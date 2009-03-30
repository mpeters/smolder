package Smolder::AuthHandler;
use CGI::Cookie;
use Smolder::AuthInfo;

my $MP2;

BEGIN {
    $MP2 = defined $ENV{MOD_PERL_API_VERSION} ? $ENV{MOD_PERL_API_VERSION} == 2 : 0;
    if ($MP2) {
        require Apache2;
        require Apache2::Const;
        Apache2::Const->import(-compile => qw(OK DECLINED FORBIDDEN AUTH_REQUIRED));
    } else {
        require Apache;
        require Apache::Constants;
        Apache::Constants->import(qw(OK DECLINED FORBIDDEN AUTH_REQUIRED));
    }
}

sub authen : method {
    my ($self, $r) = @_;
    return OK unless $r->is_initial_req();

    # check their auth info
    my $ai = $self->_get_auth_info($r);
    if ($ai->id) {
        $r->connection->user($ai->id);
    } else {
        $r->connection->user('anon');
    }
    return OK;
}

sub _get_auth_info {
    my ($self, $r) = @_;
    if (!$r->pnotes('auth_info')) {
        my $cookie = CGI::Cookie->fetch();
        my $ai     = Smolder::AuthInfo->new();
        $cookie = $cookie->{smolder};

        # make sure we have a cookie and a session
        if (ref $cookie) {
            my $value = $cookie->value;
            $ai->parse($value) if $value;
        }
        $r->pnotes(auth_info => $ai);
    }
    return $r->pnotes('auth_info');
}

sub authz : method {
    my ($self, $r) = @_;
    return OK unless $r->is_initial_req();

    my $ai = $self->_get_auth_info($r);
    my @groups = @{$ai->groups || []};

    # check our group requirements
    my $requires = $r->requires;
    foreach $req (@$requires) {
        $req = $req->{requirement};
        my ($required_group) = ($req =~ /group (\S+)/);
        if ($required_group) {

            # if they don't have any groups then they aren't
            # really logged in (just anon) so let the know they need
            # to log in
            return AUTH_REQUIRED unless @groups;
            my $found = 0;
            foreach my $g (@groups) {
                if ($g eq $required_group) {
                    $found = 1;
                    last;
                }
            }
            return FORBIDDEN unless $found;
        }
    }
    return OK;
}

1;
