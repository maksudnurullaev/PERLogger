package DBO;
{

=encoding utf8

=head1 NAME

    Db - Database I<functions> package

=cut

    use 5.012000;
    use strict;
    use warnings;
    use utf8;
    use Utils;
    use DBI;
    use DBD::SQLite;
    use Utils::Filter;
    use Data::Dumper;
    use Carp;

    my $DB_SQLite_TYPE  = 0;
    my $DB_Pg_TYPE      = 2;
    my $DB_CURRENT_TYPE = $DB_SQLite_TYPE;

    my $LINK_OBJECT_NAME = '_link_';

    my $_production_mode = 1;
    sub set_production_mode { $_production_mode = shift; }
    sub get_production_mode { $_production_mode; }

    sub new {
        my ( $class, $mojo, $path2db ) = ( shift, shift, shift );
        my $self = { mojo => $mojo };
        $self->{'file'} = $path2db if $path2db;
        if ($path2db) {
            $self->{'file'} = $path2db;
        }
        else {
            confess("Not defined database file path!");
        }
        return ( bless $self, $class );
    }

    sub is_valid {
        my $self = shift;
        return ( $self->initialize ) if !-e $self->{'file'};
        return ( -e $self->{'file'} );
    }

    sub get_db_connection {
        my $self = shift;
        return $self->{dbh}
          if exists( $self->{dbh} ) && defined( $self->{dbh} );
        if ( $DB_CURRENT_TYPE == $DB_SQLite_TYPE ) {
            my $dbi_connection_string = "dbi:SQLite:dbname=" . $self->{'file'};
            my $dbh = DBI->connect( $dbi_connection_string, undef, undef,
                { sqlite_unicode => 1, AutoCommit => 1 } );
            if ( !defined($dbh) ) {
                warn $DBI::errstr;
                return (undef);
            }
            $dbh->do("PRAGMA synchronous = OFF");
            $self->{dbh} = $dbh;
            return ($dbh);
        }
        elsif ( $DB_CURRENT_TYPE == $DB_Pg_TYPE ) {
            warn "Error:Pg: Not implemeted yet!";
            return (undef);
        }
        else {
            warn "Error:DB: Unknown db type!";
            return (undef);
        }
    }

    sub initialize {
        my $self = shift;
        return (1) if ( -e $self->{'file'} );
        if ( $DB_CURRENT_TYPE == $DB_SQLite_TYPE ) {
            my $connection = $self->get_db_connection()
              || die "Could not connect to SQLite database";
            if ( defined($connection) ) {
                my @SQLITE_INIT_SQLs = (
"CREATE TABLE objects (name TEXT, id TEXT, field TEXT, value TEXT COLLATE NOCASE);",
"CREATE INDEX i_objects ON objects (name, id, field COLLATE NOCASE);",
                );
                for my $sql (@SQLITE_INIT_SQLs) {
                    my $stmt = $connection->prepare($sql);
                    $stmt->execute
                      || die "Error:Db: Could not init database with: $sql";
                }
                return (1);
            }
        }
        else {
            warn "Error:DB: Unknown db type!";
            return (undef);
        }
    }

    sub change_name {
        my $self = shift;
        my ( $new_name, $id ) = @_;
        if ( $new_name && $id ) {
            my $dbh = $self->get_db_connection() || return;
            return $dbh->do(
                "UPDATE objects SET name = '$new_name' WHERE id = '$id' ;");
        }
        return;
    }

    sub change_id {
        my $self = shift;
        my ( $idold, $idnew ) = @_;
        if ( $idold && $idnew ) {
            my $found = $self->get_objects( { id => [$idnew] } );
            if ( $found && $self->object_valid( $found->{$idnew} ) ) {
                warn "change_id:error Object with id '$idnew' already exists!";
                return;
            }

            my $dbh = $self->get_db_connection() || return;
            return $dbh->do(
                "UPDATE objects SET id = '$idnew' WHERE id = '$idold' ;");
        }
        warn "change_id:error NEW or OLD id not defined!";
        return;
    }

    sub del {
        my ( $self, $id ) = @_;
        return if !$id;
        my $dbh   = $self->get_db_connection() || return;
        my $scope = $self->get_objects( { id => [$id], field => ['PARENT'] } );
        my $child = $scope->{$id};
        if ($child) {    # if old parent exist
                         # remove from parent's children scope
            $self->parent_remove_child( $child->{PARENT}, $id );
        }
        return $dbh->do("DELETE FROM objects WHERE id = '$id' ;");
    }

    sub update {
        my ( $self, $hashref, $dryRunMode, $object_name, $id ) =
          ( shift, shift, shift, undef, undef );

        # DRY RUN
        if ($dryRunMode) {
            Utils::print_debug( "DRY RUN UPDATE: $hashref->{id}\n" . Dumper($hashref) . "ID: " . $hashref->{id});
            return $hashref->{id};
        }

        # UPDATE    
        if (   defined($hashref)
            && defined( $hashref->{object_name} )
            && defined( $hashref->{id} ) )
        {
            $object_name = Utils::trim( $hashref->{object_name} );
            $id          = $hashref->{id};
            delete $hashref->{id};
            delete $hashref->{object_name};
        }
        else {
            warn "Error:Db:Update: No object or object name or Id!";
            return (undef);
        }
        if ( scalar( keys %{$hashref} ) == 0 ) {
            warn "Error:Db:Insert: No data!";
            return (undef);
        }
        my $dbh        = $self->get_db_connection() || return;
        my $data_old   = $self->get_objects( { id => [$id] } );
        my $sth_insert = $dbh->prepare(
            qq{ INSERT INTO objects (name,id,field,value) values(?,?,?,?); });
        my $sth_update = $dbh->prepare(
qq{ UPDATE objects SET value = ? WHERE name = ? AND id = ? AND field = ?; }
        );
        for my $field ( keys %{$hashref} ) {
            if ( exists $data_old->{$id}->{$field} )
            {    # check if such field exits already!
                $sth_update->execute( $hashref->{$field}, $object_name, $id,
                    $field );
            }
            else {
                $sth_insert->execute( $object_name, $id, $field,
                    $hashref->{$field} );
            }
        }
        return ($id);
    }

    sub insert {
        my ( $self, $hashref, $dryRunMode, $object_name ) =
          ( shift, shift, shift, undef );
        my $id  = $hashref->{id}             || Utils::get_date_uuid();
        # DRY RUN
        if ($dryRunMode) {
            Utils::print_debug( "DRY RUN INSERT: " . Dumper($hashref) . "ID: $id" );
            return ($id);
        }

        # INSERT DATA
        if ( defined($hashref) && defined( $hashref->{object_name} ) ) {
            $object_name = $hashref->{object_name};
            delete $hashref->{object_name};
        }
        else {
            warn "Error:Db:Insert: No object or object name!";
            return (undef);
        }
        if ( scalar( keys %{$hashref} ) == 0 ) {
            warn "Error:Db:Insert: No data!";
            return (undef);
        }
        
        my $dbh = $self->get_db_connection() || return;
        my $sth = $dbh->prepare(
            "INSERT INTO objects (name,id,field,value) values(?,?,?,?);");
        for my $field ( keys %{$hashref} ) {
            $sth->execute( $object_name, $id, $field, $hashref->{$field} );
        }
        return ($id);
    }

    sub object_valid {
        my $self   = shift;
        my $object = shift;
        return (undef) if !$object;
        for my $field ( keys %{$object} ) {
            return (1) if $field !~ /^_/;
        }
        return (undef);
    }

    sub format_statement2hash_objects {
        my ( $self, $sth, $params ) = @_;
        return {} if !$sth;
        my ( $name, $id, $field, $value, $result ) =
          ( undef, undef, undef, undef, {} );
        $sth->bind_columns( \( $name, $id, $field, $value ) );
        my $_no_links =
          $params && exists( $params->{no_links} ) && $params->{no_links};
        while ( $sth->fetch ) {
            $result->{$id} = {} if !exists( $result->{$id} );
            if ( $name =~ /^_/ ) {    # extended field name!!!
                next if $_no_links;
                $result->{$id}{$name} = {}
                  if !exists( $result->{$id}->{$name} );
                $result->{$id}{$name}{$value} = $field;
                if ( exists $result->{$id}{$name}{$field} ) {
                    $result->{$id}{$name}{$field}++;
                }
                else {
                    $result->{$id}{$name}{$field} = 1;
                }
            }
            else {
                $result->{$id} = { object_name => $name, id => $id }
                  if !exists( $result->{$id}->{object_name} );
                $result->{$id}{$field} = $value;
            }
        }
        return ($result) if scalar( keys %{$result} );
        return (undef);
    }

    sub get_from_sql {
        my $self       = shift;
        my $sql_string = shift;
        return (undef) if !$self || !$sql_string;

        my $dbh = $self->get_db_connection() || return (undef);
        $dbh->{FetchHashKeyName} = 'NAME_lc';
        my $sth = $dbh->prepare($sql_string);
        if ( scalar(@_) ) {
            if ( $sth->execute(@_) ) {
                return ($sth);
            }
            else { warn $DBI::errstr; }
        }
        else {
            if ( $sth->execute ) {
                return ($sth);
            }
            else { warn $DBI::errstr; }
        }
        return (undef);
    }

    sub get_objects_sql {
        my ( $self, $parameters ) = ( shift, shift );
        warn "No parameters!" && return
          if !$parameters || scalar( keys %{$parameters} ) == 0;

        my $result = "SELECT ";

        $result .= "DISTINCT "
          if exists( $parameters->{distinct} )
          && $parameters->{distinct};

        $result .= '* FROM objects ';

        my $where_part = $self->get_objects_sql_where_part($parameters);
        $result .= " WHERE id IN(
                SELECT DISTINCT id
                    FROM objects
                    WHERE $where_part) " if $where_part;

        if ( exists( $parameters->{columns} )
            && $parameters->{columns} )
        {
            my $_columns = join( ",",
                map { uc( $self->get_db_connection()->quote($_) ) }
                  @{ $parameters->{columns} } );

            if ($where_part) {
                $result .= "AND UPPER(field) in ($_columns) ";
            }
            else {
                $result .= "AND UPPER(field) in ($_columns) ";
            }
        }

        if ( exists( $parameters->{order} ) && $parameters->{order} ) {
            $result .= " $parameters->{order} ";
        }
        else {
            $result .= " ORDER BY id DESC ";
        }

        if ( exists( $parameters->{limit} ) && $parameters->{limit} ) {
            $result .= " $parameters->{limit} ";
        }

        return ("$result ;");
    }

    sub get_objects_sql_where_part {
        my $self       = shift;
        my $parameters = shift;
        my $result     = '';
        my $dbh        = $self->get_db_connection() || return;
        my @fields     = qw(id name field value);
        for my $field (@fields) {
            if ( exists( $parameters->{$field} ) && $parameters->{$field} ) {
                $result .= " AND " if $result;
                my $values = $parameters->{$field};
                my $count  = scalar( @{$values} );    # count of parameters
                if ( $count == 1 ) {
                    $result .= " $field = " . $dbh->quote( $values->[0] ) . " ";
                }
                elsif ( $count == 3 && $values->[0] =~ /^between$/i ) {
                    $result =
                        " ($field BETWEEN "
                      . $dbh->quote( $values->[1] ) . " AND "
                      . $dbh->quote( $values->[2] ) . ") ";
                }
                else {
                    $result .=
                      " $field IN ("
                      . join( ",", map { $dbh->quote($_) } @{$values} ) . ") ";
                }
            }
        }
        if ( exists $parameters->{add_where} ) {
            if ($result) {
                $result .= " AND $parameters->{add_where} ";
            }
            else {
                $result .= " WHERE $parameters->{add_where} ";
            }
        }
        return ($result);
    }

    sub get_objects {
        my $self       = shift;
        my $parameters = shift;
        if ( ref($parameters) ne "HASH" ) {
            warn "Parameters should be hash!";
            return;
        }
        my $dbh = $self->get_db_connection() || return;
        $dbh->{FetchHashKeyName} = 'NAME_lc';
        my ( $sth, $sql_string ) =
          ( undef, $self->get_objects_sql($parameters) );
        $sth = $dbh->prepare($sql_string);
        if ( $sth->execute ) {
            return (
                $self->format_statement2hash_objects( $sth, $parameters ) );
        }
        else { warn $DBI::errstr; }
        return;
    }

    sub get_filtered_objects {
        my $self          = shift;
        my $parameters    = shift;
        my $name          = $parameters->{name};
        my $names         = $parameters->{names};
        my $exist_field   = $parameters->{exist_field};
        my $filter_value  = $parameters->{filter_value};
        my $filter_prefix = $parameters->{filter_prefix};
        my $result_fields = $parameters->{result_fields};
        my $filter_where;
        my $result;

        if ($filter_value) {
            $self->{mojo}->stash( filter => $filter_value ) if $filter_value;
            if ($filter_prefix) {
                $filter_where =
" $filter_prefix AND value LIKE '%$filter_value%' escape '\\' ";
            }
            else {
                $filter_where = " value LIKE '%$filter_value%' escape '\\' ";
            }
            $result = $self->get_counts(
                { name => [$name], add_where => $filter_where } );
        }
        else {
            $result =
              $self->get_counts( { name => [$name], field => [$exist_field] } );
        }
        return if !$result;    # count is 0
        my ( $page, $pages, $pagesize ) =
          Utils::Filter::setup_pages( $self->{mojo}, $result );
        $self->{mojo}->stash( paginator => [ $page, $pages, $pagesize ] );
        my ( $limit, $offset ) =
          ( " limit $pagesize ", $pagesize * ( $page - 1 ) );
        $limit .= " offset $offset " if $offset;

        # find real records if exist
        if ($filter_value) {
            $result = $self->get_objects(
                {
                    name      => [$name],
                    add_where => $filter_where,
                    limit     => $limit
                }
            );
        }
        else {
            $result = $self->get_objects(
                {
                    name  => [$name],
                    field => [$exist_field],
                    limit => $limit
                }
            );
        }

        # final
        map {
            $result->{$_} = $self->get_objects(
                {
                    name  => [$name],
                    field => $result_fields
                }
            )->{$_}
          }
          keys %{$result};
        return ($result);
    }

    sub get_counts {
        my $self       = shift;
        my $parameters = shift;
        if ( ref($parameters) ne "HASH" ) {
            warn "Parameters should be hash!";
            return;
        }
        my $dbh = $self->get_db_connection() || return;
        $dbh->{FetchHashKeyName} = 'NAME_lc';
        my $where_part = $self->get_objects_sql_where_part($parameters);
        my ($count) = $dbh->selectrow_array(
            " SELECT COUNT(*) FROM objects WHERE $where_part ;");
        return ($count);
    }

    sub get_user {
        my $self  = shift;
        my $email = shift;
        return (undef) if !$email;

        my $users = $self->get_objects(
            {
                name      => ['user'],
                add_where => " field='email' AND value='$email' "
            }
        );
        my @ids   = keys %{$users};
        my $count = scalar(@ids);
        if ( !$count ) {
            warn "User with email '$email' not exist";
            return (undef);
        }
        if ( scalar(@ids) != 1 ) {
            warn "User with email '$email' not unique: $count!";
            return (undef);
        }

        # make map
        my $user_id = $ids[0];
        $users = $self->get_objects(
            {
                name      => ['user'],
                field     => [ 'email', 'password', 'extended_right' ],
                add_where => " name='user' AND id='$user_id' "
            }
        );
        return (undef)
          if !$users
          || !exists( $users->{$user_id} )
          || !exists( $users->{$user_id}{password} );
        return ( $users->{$user_id} );
    }

    # -= access to linked value between two objects =-
    # Note: ALWAYS: ID1 < ID2
    # example:
    # ==============================
    # | name   | id  | field | value |
    # ==============================
    # | access | id1 | id2   | value |
    # ------------------------------
    sub get_linked_value {
        my $self = shift;
        my ( $name, $id1, $id2 ) = @_;
        return if ( !$name || !$id1 || !$id2 || ( $id1 eq $id2 ) );
        ( $id1, $id2 ) = ( $id2, $id1 ) if $id1 gt $id2;  # impotant test & swap
        my $dbh = $self->get_db_connection() || return;
        $dbh->{FetchHashKeyName} = 'NAME_lc';
        my $sth_str =
          "SELECT value FROM objects WHERE name=? AND id=? AND field=? ;";
        my $sth = $dbh->prepare($sth_str);

        if ( $sth->execute( $name, $id1, $id2 ) ) {
            my $value;
            $sth->bind_columns( \($value) );
            if ( $sth->fetch ) {
                return ($value);
            }
            return (undef);
        }
        warn $DBI::errstr;
        return (undef);    # some error happens
    }

    sub set_linked_value {
        my $self = shift;
        my ( $name, $id1, $id2, $value ) = @_;
        return if ( !$name || !$id1 || !$id2 || !$value || ( $id1 eq $id2 ) );
        ( $id1, $id2 ) = ( $id2, $id1 ) if $id1 gt $id2;  # impotant test & swap
        my $dbh = $self->get_db_connection() || return;
        if ( get_linked_value( $name, $id1, $id2 ) ) {
            my $sth = $dbh->prepare(
"UPDATE objects SET value = ? WHERE name =? AND id = ? AND field =? ;"
            );
            return (0) if !$sth->execute( $value, $name, $id1, $id2 );
        }
        else {
            my $sth = $dbh->prepare(
                "INSERT INTO objects (name,id,field,value) values(?,?,?,?);");
            return (0) if !$sth->execute( $name, $id1, $id2, $value );
        }
        return (1);
    }

    sub del_linked_value {
        my $self = shift;
        my ( $name, $id1, $id2 ) = @_;
        return if ( !$name || !$id1 || !$id2 );
        ( $id1, $id2 ) = ( $id2, $id1 ) if $id1 gt $id2;  # impotant test & swap
        my $dbh = $self->get_db_connection() || return;
        return $dbh->do(
"DELETE FROM objects WHERE name='$name' AND id='$id1' AND field='$id2';"
        );
    }

    # -= links betweeen two objects =-
    # ==============================
    # | name | id  | field | value |
    # ==============================
    # | link | id1 | name2 | id2   |
    # ------------------------------
    sub exists_link {
        my $self = shift;
        my ( $id1, $id2 ) = @_;
        return if ( !$id1 || !$id2 );
        my $dbh = $self->get_db_connection() || return;
        $dbh->{FetchHashKeyName} = 'NAME_lc';
        my $sth_str =
          "SELECT COUNT(*) FROM objects WHERE name=? AND id=? AND value=? ;";
        my $sth = $dbh->prepare($sth_str);
        if ( $sth->execute( $LINK_OBJECT_NAME, $id1, $id2 ) ) {
            my ($count) = $sth->fetchrow_array;
            return $count;
        }
        warn $DBI::errstr;
        return (undef);    # some error happens
    }

    sub set_link {
        my ( $self, $id1, $id2, $dryRunMode ) = @_;

        # DRY RUN MODE
        if($dryRunMode){
            Utils::print_debug("DRY RUN SET_LINK($id1, $id2)");
            return(1);
        }

        # set link
        return (0) if ( !$self || !$id1 || !$id2 );
        return (1) if exists_link( $id1, $id2 );

        my ( $name1, $name2 ) = (
            $self->get_object_name_by_id($id1),
            $self->get_object_name_by_id($id2)
        );

        return (0) if !$name1 || !$name2;

        my $dbh = $self->get_db_connection() || return;
        my $sth = $dbh->prepare(
            'INSERT INTO objects (name,id,field,value) values(?,?,?,?);');
        return (0) if !$sth->execute( $LINK_OBJECT_NAME, $id1, $name2, $id2 );
        return (0) if !$sth->execute( $LINK_OBJECT_NAME, $id2, $name1, $id1 );
        return (1);
    }

    sub links_attach {
        my ( $self, $result, $links_name, $link_name, $fields ) = @_;
        for my $id ( keys %{$result} ) {
            my $links = $self->get_links( $id, $link_name, $fields );
            for my $link_id ( keys %{$links} ) {
                $result->{$id}->{$links_name} = {}
                  if !exists( $result->{$id}->{$links_name} );
                my $link_object = $self->get_objects(
                    {
                        id    => [$link_id],
                        name  => [$link_name],
                        field => $fields
                    }
                );
                $result->{$id}{$links_name}{$link_id} = $link_object->{$link_id}
                  if $link_object;
            }
        }
    }

    sub get_links {
        my ( $self, $id1, $name2, $fields ) = @_;
        return if ( !$name2 || !$id1 );
        my $dbh = $self->get_db_connection() || return;
        $dbh->{FetchHashKeyName} = 'NAME_lc';
        my $sth_str =
"SELECT DISTINCT value FROM objects WHERE name=? AND id=? AND field=? ;";
        my $sth = $dbh->prepare($sth_str);
        my ( $link_id, $result ) = ( undef, {} );
        if ( $sth->execute( $LINK_OBJECT_NAME, $id1, $name2 ) ) {
            $sth->bind_columns( \($link_id) );
            while ( $sth->fetch ) {
                my $object;
                $object = (
                    $fields
                    ? $self->get_objects(
                        { id => [$link_id], columns => $fields }
                      )
                    : $self->get_objects( { id => [$link_id] } )
                );
                $result->{$link_id} = $object->{$link_id} if $object;
            }
        }
        else { warn $DBI::errstr; }
        return ($result) if scalar keys %{$result};
        return (undef);
    }

    sub get_difference {
        my ( $self, $id, $link_object_name, $field ) = @_;
        my ( $all_, $links_ ) = (
            $self->get_objects(
                { name => [$link_object_name], field => [$field] }
            ),
            $self->get_links( $id, $link_object_name, [$field] )
        );
        my ( $all, $links ) = ( [], [] );
        for my $link_id ( keys %{$links_} ) {
            push @{$links}, [ $links_->{$link_id}->{$field} => $link_id ]
              if exists( $all_->{$link_id} );
        }
        for my $all_id ( keys %{$all_} ) {
            push @{$all}, [ $all_->{$all_id}->{$field} => $all_id ]
              if !exists( $links_->{$all_id} );
        }
        return ( $all, $links );
    }

    sub del_link {
        my ( $self, $id1, $id2 ) = @_;
        return if ( !$id1 || !$id2 );
        my $dbh = $self->get_db_connection() || return;
        $dbh->do(
"DELETE FROM objects WHERE name='$LINK_OBJECT_NAME' AND id = '$id1' AND value = '$id2' ;"
        );
        return $dbh->do(
"DELETE FROM objects WHERE name='$LINK_OBJECT_NAME' AND id = '$id2' AND value = '$id1' ;"
        );
    }

    # -= parent & child functionality =-
    sub child_set_parent {
        my ( $self, $id, $parent_id ) = @_;
        my $scope = $self->get_objects(
            { id => [$id], field => [ 'creator', 'PARENT' ] } );
        my $child = $scope->{$id};
        if ( exists( $child->{PARENT} ) ) {    # if old parent exist
                # remove from children for old parent
            $self->parent_remove_child( $child->{PARENT}, $id );
        }

        # set new parent
        $child->{PARENT} = $parent_id;
        $self->update($child);

        # add this child to new parent
        $self->parent_add_child( $parent_id, $id );
    }

    sub parent_remove_child {
        my ( $self, $parent_id, $id ) = @_;
        my $scope = $self->get_objects(
            { id => [$parent_id], field => [ 'creator', 'CHILDREN' ] } );
        my $parent = $scope->{$parent_id};
        $parent->{CHILDREN} =~ s/$id//g;
        $parent->{CHILDREN} =~ s/,{2,}/,/g;
        $parent->{CHILDREN} =~ s/,$//g;
        $parent->{CHILDREN} =~ s/^,//g;
        $parent->{CHILDREN} =~ s/^,$//g;

        if ( !$parent->{CHILDREN} ) {    # no more children
            $self->get_from_sql(
"delete from objects where id = '$parent_id' and field = 'CHILDREN' ; "
            );
        }
        else {
            $self->update($parent);
        }
    }

    sub child_make_root {
        my ( $self, $id ) = @_;
        my $scope = $self->get_objects(
            { id => [$id], field => [ 'creator', 'PARENT' ] } );
        my $child = $scope->{$id};
        return if !exists( $child->{PARENT} );

        my $parent_id = $child->{PARENT};
        $self->parent_remove_child( $parent_id, $id );
        $self->get_from_sql(
            "delete from objects where id = '$id' and field = 'PARENT' ; ");
    }

    sub parent_add_child {
        my ( $self, $parent_id, $id ) = @_;
        my $scope = $self->get_objects(
            { id => [$parent_id], field => [ 'creator', 'CHILDREN' ] } );
        my $parent = $scope->{$parent_id};
        if ( exists( $parent->{CHILDREN} ) ) {
            $parent->{CHILDREN} .= ",$id";
        }
        else {
            $parent->{CHILDREN} = $id;
        }
        $self->update($parent);
    }

    sub get_root_parents {
        my ( $self, $where_sql ) = @_;
        return if !$where_sql;

        # PARENTS
        # we needs two parents: one for get key->object, second for traverse
        my $parents_root = {};
        my $sth =
          $self->get_from_sql(" SELECT DISTINCT id FROM objects $where_sql ; ");
        my $id = undef;
        $sth->bind_col( 1, \$id );
        while ( $sth->fetch ) {
            $parents_root->{$id} = 0;
        }

        # PARENTS WITH CHILD
        # generate CHILD->PARENT links
        my $parents_with_childs = {};
        $sth = $self->get_from_sql(
" SELECT DISTINCT id, value FROM objects $where_sql AND field = 'PARENT' ; "
        );
        $sth->bind_col( 1, \$id );
        my $parent = undef;
        $sth->bind_col( 2, \$parent );
        while ( $sth->fetch ) {
            delete $parents_root->{$id};
        }
        return ($parents_root);
    }

    sub get_parent_childs {
        my ( $self, $parent_id, $fields ) = @_;
        my $scope =
          $self->get_objects( { id => [$parent_id], field => $fields } );
        my $parent = $scope->{$parent_id};
        if ( exists( $parent->{CHILDREN} ) ) {
            my @childs = split /,/, $parent->{CHILDREN};
            for my $id (@childs) {
                next if !$id;
                $parent->{CHILDREN} = {}
                  if ref( $parent->{CHILDREN} ) ne 'HASH';
                $parent->{CHILDREN}{$id} =
                  $self->get_parent_childs( $id, $fields );
            }
        }
        return ($parent);
    }

    sub get_object_name_by_id {
        my ( $self, $id ) = @_;
        my $sql =
" SELECT DISTINCT name FROM objects WHERE id = '$id' AND name NOT LIKE '\\_%' ESCAPE '\\' ; ";
        my $sth = $self->get_from_sql($sql);
        my $name;
        $sth->bind_col( 1, \$name );
        return ($name) if $sth->fetch;
        return (undef);
    }

    sub get_filtered_objects2 {
        my ( $self, $params ) = @_;

        # 1. Get filtered object ids
        my $ids = [];
        for my $id ( $self->get_filtered_ids($params) ) {
            push @{$ids}, $id;
        }
        return ( {} ) if !scalar( @{$ids} );    # return empty hash ref
                                                # 2. Setup paginator
        my ( $page, $pages, $pagesize ) =
          Utils::Filter::setup_pages( $self->{mojo}, scalar( @{$ids} ) );
        my $start_index = ( $page - 1 ) * $pagesize;
        my $end_index   = $start_index + $pagesize - 1;

        # 3. Final actions
        my $rids = [];
        @{$rids} = ( reverse @{$ids} )[ $start_index .. $end_index ];
        return (
            $self->get_objects( { id => $rids, field => $params->{fields} } ) );
    }

    sub get_filtered_ids {
        my ( $self, $params ) = @_;
        my $temp_hash = {};

        # 1. Look in parent objects
        my $sql =
            "SELECT id,value FROM objects WHERE name = '"
          . $params->{'object_name'}
          . "' AND field NOT IN ('creator','counting_field') ;";
        my $sth = $self->get_from_sql($sql);
        for my $id ( @{ $sth->fetchall_arrayref() } ) {
            if ( eval("'$id->[1]' =~ /$params->{filter_value}/i") ) {
                $temp_hash->{ $id->[0] } = { name => $params->{object_name} };
            }
            else { warn $@ if $@; }
        }

        # 2. Look in child objects
        my $child_names = join ',',
          map { qq/'$_'/ } @{ $params->{child_names} };
        return ( keys %{$temp_hash} ) if !$child_names;
        $sql =
" SELECT c.id cid, p.value pid, c.name name,  c.value value FROM objects c "
          . " JOIN objects p ON p.name = '_link_' AND p.field = '$params->{object_name}' AND c.id = p.id "
          . " WHERE c.name IN($child_names) AND c.field != 'creator' ;";
        $sth = $self->get_from_sql($sql);
        for my $id ( @{ $sth->fetchall_arrayref() } ) {
            if ( eval("'$id->[3]' =~ /$params->{filter_value}/i") ) {
                $temp_hash->{ $id->[1] } = { name => $params->{object_name} }
                  if !exists $temp_hash->{ $id->[1] };
            }
            else { warn $@ if $@; }
        }

        # 3. Parse childs to linked parent object, if not existance
        for my $key ( keys %{$temp_hash} ) {
            if ( $temp_hash->{$key}->{name} ne $params->{object_name} ) {
                warn $temp_hash->{$key}->{name};
            }

        }
        return ( keys %{$temp_hash} );
    }

};

1;

__END__

=head1 AUTHOR

    M.Nurullaev <maksud.nurullaev@gmail.com>


