package Smolder::Constraints;
use strict;
use warnings;
use Smolder::DB;
use Smolder::DB::SmokeReport;
use Smolder::DB::Preference;
use Email::Valid;
use File::Basename;
use File::Temp;
use File::MMagic;
use File::Spec::Functions qw(catdir tmpdir);

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
  email
  unsigned_int
  bool
  length_max
  length_min
  length_between
  enum_value
  unique_field_value
  existing_field_value
  file_mtype
  smoke_report_tags
);

=head1 NAME

Smolder::Constraints

=head1 SYNOPSIS

    use Smolder::Constraints qw(email unsigned_int max_length);

    # then in a D::FV profile
    my $form = {
        required    => [qw(email id last_name)],
        constraint_methods  => {
            email       => email(),
            id          => unsigned_int(),
            last_name   => max_length(255),
        }
    };

=head1 DESCRIPTION

This package provides/exports several routines that are useful
inside of Smolder for form validation, using L<Data::FormValidator>.
Each routine will return something suitable for use inside of
a C<constraint_methods> hash.

=head1 ROUTINES

=head2 email

Returns a method which validates an email address

=cut

sub email {
    return sub {
        my ($dfv, $value) = @_;
        if (Email::Valid->address($value)) {
            return $value;
        } else {
            return;
        }
    };
}

=head2 unsigned_int

Returns regex that assures the data is simply an unsigned integer

=cut

sub unsigned_int {
    return qr/^\d+$/;
}

=head2 bool

Returns a regex that assures the data is either a '1' or a '0'

=cut

sub bool {
    return qr/^1|0$/;
}

=head2 length_max

Given an integer $max, returns a regex that assures the data has 
at most $max number of printable characters.

=cut

sub length_max {
    my $max = shift;
    return qr/^[[:print:]\s]{1,$max}$/;
}

=head2 length_min

Given an integer $min, returns a regex that assures the data has
at least $min number of printable characters.

=cut

sub length_min {
    my $min = shift;
    return qr/^[[:print:]\s]{$min,}$/;
}

=head2 length_between

Given an integer $min and an integer $max, returns a regex that assures the data has
at least $min and at most $max number of printable characters.

=cut

sub length_between {
    my ($min, $max) = sort { $a <=> $b } @_;
    return qr/^[[:print:]]{$min,$max}$/;
}

=head2 enum_value

Returns a method which will make sure that the value is an allowable
enum value for the given table and column.

    enum_value('table', 'column');

=cut

sub enum_value {
    my ($table, $column) = @_;
    my $enums = Smolder::DB->enum_values($table, $column);
    return sub {
        my ($dfv, $value) = @_;
        foreach my $enum (@$enums) {
            if ($enum eq $value) {
                return $value;
            }
        }
        return;
    };
}

=head2 unique_field_value

Returns a method which will make sure that the value
being updated does not currently exist in the table and field
specified.  Can be passed an optional integer value which is 
used as the table's primary id to not compare against 
(this is useful when editing an existing row when you don't 
care it still has the same value or not).

    unique_field_value('project', 'name')

or

    unique_field_value('developer', 'username', 23)

=cut

sub unique_field_value {
    my ($table, $field, $id) = @_;

    return sub {
        my ($dfv, $value) = @_;
        $dfv->set_current_constraint_name("unique_${table}_${field}");

        # get all the values of a certain field
        my $sql = "SELECT $field FROM $table WHERE $field = ?";
        $sql .= " AND id != $id" if ($id);
        my $sth = Smolder::DB->db_Main->prepare_cached($sql);
        $sth->execute($value);
        my $row = $sth->fetchrow_arrayref();
        $sth->finish();
        if ($row) {
            return;
        } else {
            return $value;
        }
      }
}

=head2 existing_field_value 

Returns a sub that will verifiy that a value exists in a particular
table in a particular column.

    existing_field_value('developer', 'id')

=cut 

sub existing_field_value {
    my ($table, $column) = @_;
    return sub {
        my ($dfv, $value) = @_;
        my $sth = Smolder::DB->db_Main->prepare_cached(
            qq(
            SELECT $column FROM $table WHERE $column = ?
        )
        );
        $sth->execute($value);
        my $row = $sth->fetchrow_arrayref();
        $sth->finish();
        if (defined $row->[0]) {
            return $value;
        } else {
            return;
        }
      }
}

=head2 file_mtype

Returns a sub that will validate that the file is one of the given MIME types.
If it is valid, it will return the name of the temporary file currently
being used.

    file_mtype('text/plain', 'image/jpg'),

=cut

sub file_mtype {
    my @types = @_;
    return sub {
        my ($dfv, $filename) = @_;
        my $fh = $dfv->get_input_data()->upload($dfv->get_current_constraint_field);
        my ($suffix) = (basename($filename) =~ /(\..*)$/);

        # save the file to a temp location
        my $tmp = File::Temp->new(
            UNLINK => 0,
            SUFFIX => ($suffix || '.tmp'),
            DIR    => tmpdir(),
        ) or die "Could not create tmp file!";
        while (my $line = <$fh>) {
            print $tmp $line or die "Could not print to file '$tmp': $!";
        }
        close($tmp) or die "Could not close file '$tmp': $!";
        close($fh)  or die "Could not close upload FH: $!";

        # now get the file's mime-type
        my $mm   = File::MMagic->new();
        my $type = $mm->checktype_filename($tmp->filename);
        foreach my $t (@types) {
            if ($t eq $type) {
                return $tmp->filename;
            }
        }

        # if we got here then it wasn't valid, so remove the temp file
        unlink($tmp->filename) or die "Could not remove file '$tmp': $!";
        return;
      }
}

=head2 smoke_report_tags

Returns a sub that will verifiy that a value is a comma separated list
of tags that are no more than 255 characters each. If they are valid,
then an array ref of the tags will be returned.

    smoke_report_tags()

=cut 

sub smoke_report_tags {
    return sub {
        my ($dfv, $value) = @_;

        my @words = split(/\s*,\s*/, $value);
        foreach my $word (@words) {
            return if length $word > 255;
        }
        return \@words;
      }
}

1;
