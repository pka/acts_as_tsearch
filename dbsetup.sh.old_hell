
#
# See if tsearch2.sql exists on the system
#
sqlfile=$(locate /tsearch2.sql)
if [ -z "$sqlfile"]
then
	echo "tsearch2.sql was not found on this system - please see http://code.google.com/p/acts-as-tsearch/wiki/PreparingYourPostgreSQLDatabase for details."
	exit 
fi

#
# Check that they ran this as postgres
#
if [ "$LOGNAME" != "root" ]
then
	echo "This script needs to be run as user root"
	echo "Try "
	echo "    su root"
	echo "      or"
	echo "    sudo su root"
	exit 
fi

#
# Check required parameters
#
db=${1}
un=${2}
if [ -z "$1" "$2" ]
then
	echo "Usage: `basename $0 $1` db-name db-username"
	echo "Example: `basename $0 $1` tsearch wiseleyb"
	echo "     would setup database tsearch for database username wiseleyb"
	exit $E_NOARGS
fi

echo "create user $un;
alter user $un with password '$un';
grant all on database $db to $un;
grant all on public.pg_ts_cfg to $un;
grant all on public.pg_ts_cfgmap to $un; 
grant all on public.pg_ts_dict to $un; 
grant all on public.pg_ts_parser to $un;" > tmp_db_setup_grant_file.sql

su postgres << EOF
#
# Load sql file
#
psql $db < $sqlfile

#
# Grant permissions
#
psql $db < tmp_db_setup_grant_file.sql
EOF
rm tmp_db_setup_grant_file.sql