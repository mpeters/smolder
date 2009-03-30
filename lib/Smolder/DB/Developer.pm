package Smolder::DB::Developer;
use strict;
use warnings;
use base 'Smolder::DB';
use Data::Random qw(rand_chars);
use Smolder::DB::Project;

__PACKAGE__->set_up_table('developer');

=head1 NAME

Smolder::DB::Developer

=head1 DESCRIPTION

L<Class::DBI> based model class for the 'developer' table in the database.

=head1 METHODS

=head2 ACCESSSOR/MUTATORS

Each column in the borough table has a method with the same name
that can be used as an accessor and mutator.

The following columns will return objects instead of the value contained in the table:

=cut

# encrypt the password if we are creating or updating
__PACKAGE__->add_trigger(before_create => \&_crypt_password,);
__PACKAGE__->add_trigger(before_update => \&_crypt_if_changed,);

# make sure we delete a preference when we are deleted
__PACKAGE__->add_trigger(
    after_delete => sub {
        my $self = shift;
        $self->preference->delete() if $self->preference;
    },
);

=over

=item preference

This is their default, L<Smolder::DB::Preference> object.

=cut

__PACKAGE__->has_a(preference => 'Smolder::DB::Preference');

=item project_developers

Returns a list of L<Smolder::DB::ProjectDeveloper> objects that are connected to this
Developer.

=cut

__PACKAGE__->has_many('project_developers' => 'Smolder::DB::ProjectDeveloper');

=item smoke_reports

A list of L<Smolder::DB::SmokeReport> that were added by this Developer.

=cut

__PACKAGE__->has_many('smoke_reports' => 'Smolder::DB::SmokeReport');

=back

=head2 OBJECT METHODS

=head3 project_pref

Given a L<Smolder::DB::Project> object, this returns the L<Smolder::DB::Preference>
object associated with that project and this Developer.

=cut

sub project_pref {
    my ($self, $project) = @_;
    my $sth = $self->db_Main->prepare_cached(
        qq(
        SELECT preference.* FROM preference, project_developer
        WHERE preference.id = project_developer.preference 
        AND project_developer.developer = ?
        AND project_developer.project = ?
    )
    );
    $sth->execute($self->id, $project->id);

    # there should be only one, but it returns an iterator unless
    # in list context
    my @prefs = Smolder::DB::Preference->sth_to_objects($sth);
    return $prefs[0];
}

=head3 full_name

Returns the full name of the Developer, in the following format:

    First Last

=cut

sub full_name {
    my $self = shift;
    return $self->fname . ' ' . $self->lname;
}

=head3 email_hidden

Returns the email address in HTML formatted to foil email harvesting bots.
For example, the email address
    
    test@example.com

Will become

    TODO

=cut

sub email_hidden {
    my $self = shift;

    # TODO - hide somehow
    return $self->email;
}

=head3 reset_password

Creates a new random password of between 6 and 8 characters suitable and
sets it as this Developer's password. This new password is returned unencrypted.

=cut

sub reset_password {
    my $self = shift;
    my $new_pw = join('', rand_chars(set => 'alphanumeric', min => 6, max => 8, shuffle => 1));
    $self->set('password' => $new_pw);
    $self->update();

    return $new_pw;
}

=head3 projects

Returns an array ref of all the L<Smolder::DB::Project>s that this Developer is a member
of (using the C<project_developer> join table).

=cut

sub projects {
    my $self = shift;
    my $sth  = $self->db_Main->prepare_cached(
        qq(
        SELECT project.* FROM project, project_developer
        WHERE project_developer.project = project.id AND project_developer.developer = ?
        ORDER BY project_developer.added
    )
    );
    $sth->execute($self->id);
    return Smolder::DB::Project->sth_to_objects($sth);
}

=head3 groups

Returns the names of the groups this developer is in

=cut

sub groups {
    my $self = shift;
    my @groups;
    push(@groups, 'developer') if !$self->guest;
    push(@groups, 'admin')     if $self->admin;
    return @groups;
}

=head2 CLASS METHODS

=head2 get_guest

This method will return a user 'anonymous' who is marked as a 'guest'. If this
user does not exist, one will be created.

=cut

sub get_guest {
    my $pkg = shift;
    my ($guest) = $pkg->search(
        guest    => 1,
        username => 'anonymous',
    );

    unless ($guest) {
        my $fake_pw = join(
            '',
            rand_chars(
                set     => 'alphanumeric',
                min     => 6,
                max     => 8,
                shuffle => 1
            )
        );
        $guest = $pkg->create(
            {
                guest      => 1,
                username   => 'anonymous',
                password   => $fake_pw,
                preference => Smolder::DB::Preference->create({email_freq => 'never'}),
            }
        );
    }

    return $guest;
}

sub _crypt_password {
    my $self = shift;
    my $salt = join('', rand_chars(set => 'alphanumeric', size => 2, shuffle => 1));
    my ($pw) = ($self->_attrs('password'));
    if ($pw) {
        $self->_attribute_set(password => crypt($pw, $salt));
    }
}

sub _crypt_if_changed {
    my $self = shift;
    if (grep { $_ eq 'password' } $self->is_changed()) {
        $self->_crypt_password();
    }
}

1;

