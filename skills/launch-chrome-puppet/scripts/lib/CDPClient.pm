package CDPClient;

use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use Digest::SHA qw(sha1);
use MIME::Base64 qw(encode_base64);
use JSON::PP;
use Encode qw(encode_utf8 decode_utf8);

use constant WS_GUID  => '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
use constant OP_TEXT   => 0x1;
use constant OP_CLOSE  => 0x8;
use constant OP_PING   => 0x9;

sub new {
    my ($class, %args) = @_;
    bless {
        port      => $args{port},
        target_id => $args{target_id},
        socket    => undef,
        msg_id    => 0,
        timeout      => $args{timeout} // 30,
        _buffer      => '',
        _event_queue => [],
    }, $class;
}

# --- Public API ---

sub connect {
    my ($self) = @_;
    my ($host, $port) = ('localhost', $self->{port});

    my $sock = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => $self->{timeout},
    ) or die "Cannot connect to $host:$port: $!\n";

    binmode $sock;
    $self->{socket} = $sock;
    $self->_ws_handshake($host, $port, "/devtools/page/$self->{target_id}");
    return 1;
}

sub send_command {
    my ($self, $method, $params) = @_;
    $params //= {};

    my $id = ++$self->{msg_id};
    $self->_send_frame(JSON::PP->new->utf8->encode({
        id => $id, method => $method, params => $params,
    }));

    while (1) {
        my $raw = $self->_read_message()
            // die "Timeout waiting for response to $method\n";
        my $msg = JSON::PP->new->utf8->decode($raw);

        # Buffer events so wait_for_event can find them later
        unless (exists $msg->{id}) {
            push @{$self->{_event_queue}}, $msg;
            next;
        }

        next unless $msg->{id} == $id;

        return $msg->{error}
            ? { ok => 0, error => $msg->{error}{message} // 'CDP error' }
            : { ok => 1, result => $msg->{result} // {} };
    }
}

sub wait_for_event {
    my ($self, $event_name, $timeout) = @_;
    $timeout //= 30;

    # Drain queued events first (buffered by send_command)
    my @keep;
    for my $msg (@{$self->{_event_queue}}) {
        if (($msg->{method} // '') eq $event_name) {
            $self->{_event_queue} = \@keep;
            return $msg->{params} // {};
        }
        push @keep, $msg;
    }
    $self->{_event_queue} = \@keep;

    # Then read from socket
    my $deadline = time() + $timeout;
    while (time() < $deadline) {
        my $remaining = $deadline - time();
        $remaining = 0.1 if $remaining < 0.1;

        my $raw = $self->_read_message($remaining);
        return undef unless defined $raw;

        my $msg = JSON::PP->new->utf8->decode($raw);
        return $msg->{params} // {}
            if ($msg->{method} // '') eq $event_name;
    }
    undef;
}

sub disconnect {
    my ($self) = @_;
    return unless $self->{socket};

    # Send close frame with status 1000 (normal)
    my $frame = pack('C', 0x88) . pack('C', 0x82); # FIN+close, masked+2 bytes
    my @m = map { int(rand(256)) } 1..4;
    $frame .= pack('C4', @m);
    $frame .= chr(0x03 ^ $m[0]) . chr(0xE8 ^ $m[1]); # status 1000 masked
    eval { syswrite($self->{socket}, $frame) };

    close $self->{socket};
    $self->{socket} = undef;
}

sub DESTROY { $_[0]->disconnect }

# --- WebSocket internals ---

sub _ws_handshake {
    my ($self, $host, $port, $path) = @_;
    my $sock = $self->{socket};

    my $key = encode_base64(join('', map { chr(int(rand(256))) } 1..16), '');

    syswrite($sock, join("\r\n",
        "GET $path HTTP/1.1",
        "Host: $host:$port",
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Key: $key",
        "Sec-WebSocket-Version: 13",
        "", "",
    )) or die "Handshake write failed: $!\n";

    # Read response headers
    my $resp = '';
    my $sel = IO::Select->new($sock);
    while (1) {
        die "Handshake timeout\n" unless $sel->can_read(10);
        sysread($sock, my $chunk, 4096) or die "Closed during handshake\n";
        $resp .= $chunk;
        last if $resp =~ /\r\n\r\n/;
    }

    die "WebSocket upgrade failed\n" unless $resp =~ /^HTTP\/1\.1 101/;

    my $expected = encode_base64(sha1($key . WS_GUID), '');
    die "Bad Sec-WebSocket-Accept\n"
        unless $resp =~ /Sec-WebSocket-Accept:\s*(\S+)/i && $1 eq $expected;

    # Save any data received after the headers (start of first frame)
    if ($resp =~ /\r\n\r\n(.+)$/s) {
        $self->{_buffer} = $1;
    }
}

sub _read_exactly {
    my ($self, $len, $deadline) = @_;
    $deadline //= time() + $self->{timeout};
    my $buf = '';

    # Drain internal buffer first
    if (length $self->{_buffer}) {
        if (length($self->{_buffer}) >= $len) {
            $buf = substr($self->{_buffer}, 0, $len);
            $self->{_buffer} = substr($self->{_buffer}, $len);
            return $buf;
        }
        $buf = $self->{_buffer};
        $self->{_buffer} = '';
    }

    my $sel = IO::Select->new($self->{socket});

    while (length($buf) < $len) {
        my $remaining = $deadline - time();
        die "Read timeout\n" if $remaining <= 0;
        die "Read timeout\n" unless $sel->can_read($remaining);

        my $n = sysread($self->{socket}, my $chunk, $len - length($buf));
        die "Socket read error: $!\n" unless defined $n;
        die "Connection closed\n"     if $n == 0;
        $buf .= $chunk;
    }
    $buf;
}

sub _send_frame {
    my ($self, $text) = @_;
    my $payload = encode_utf8($text);
    my $len = length $payload;

    # Header: FIN + text opcode
    my $hdr = pack('C', 0x81);

    # Length + mask bit
    if    ($len < 126)   { $hdr .= pack('C',   0x80 | $len) }
    elsif ($len < 65536) { $hdr .= pack('Cn',  0xFE, $len)  }
    else                 { $hdr .= pack('CNN', 0xFF, 0, $len) }

    # 4-byte mask key
    my @mask = map { int(rand(256)) } 1..4;
    $hdr .= pack('C4', @mask);

    # Masked payload
    my $masked = '';
    for my $i (0 .. $len - 1) {
        $masked .= chr(ord(substr($payload, $i, 1)) ^ $mask[$i % 4]);
    }

    syswrite($self->{socket}, $hdr . $masked) or die "Frame write failed: $!\n";
}

sub _read_frame {
    my ($self, $timeout) = @_;
    $timeout //= $self->{timeout};
    my $deadline = time() + $timeout;

    # Check for data availability (skip if buffer has data)
    unless (length $self->{_buffer}) {
        my $sel = IO::Select->new($self->{socket});
        return () unless $sel->can_read($timeout);
    }

    my $hdr = $self->_read_exactly(2, $deadline);
    my ($b0, $b1) = unpack('CC', $hdr);

    my $fin    = ($b0 >> 7) & 1;
    my $opcode = $b0 & 0x0F;
    my $masked = ($b1 >> 7) & 1;
    my $len    = $b1 & 0x7F;

    # Extended length
    if ($len == 126) {
        $len = unpack('n', $self->_read_exactly(2, $deadline));
    } elsif ($len == 127) {
        my ($hi, $lo) = unpack('NN', $self->_read_exactly(8, $deadline));
        die "Frame >4 GB\n" if $hi;
        $len = $lo;
    }

    # Mask key (server→client typically unmasked, but handle it)
    my @mask;
    @mask = unpack('C4', $self->_read_exactly(4, $deadline)) if $masked;

    # Payload
    my $payload = $len ? $self->_read_exactly($len, $deadline) : '';

    if ($masked && $len) {
        $payload = join '', map {
            chr(ord(substr($payload, $_, 1)) ^ $mask[$_ % 4])
        } 0 .. length($payload) - 1;
    }

    ($opcode, $payload, $fin);
}

sub _send_pong {
    my ($self, $data) = @_;
    my $len = length $data;
    my $frame = pack('CC', 0x8A, 0x80 | $len); # FIN+pong, masked
    my @m = map { int(rand(256)) } 1..4;
    $frame .= pack('C4', @m);
    $frame .= join '', map {
        chr(ord(substr($data, $_, 1)) ^ $m[$_ % 4])
    } 0 .. $len - 1 if $len;
    syswrite($self->{socket}, $frame);
}

sub _read_message {
    my ($self, $timeout) = @_;
    $timeout //= $self->{timeout};
    my $deadline = time() + $timeout;
    my $buf = '';

    while (1) {
        my $remaining = $deadline - time();
        return undef if $remaining <= 0;

        my ($op, $payload, $fin) = $self->_read_frame($remaining);
        return undef unless defined $op;

        # Handle control frames
        if ($op == OP_PING)  { $self->_send_pong($payload); next }
        if ($op == OP_CLOSE) { die "WebSocket closed by server\n" }

        $buf .= $payload;
        return decode_utf8($buf) if $fin;
    }
}

1;
