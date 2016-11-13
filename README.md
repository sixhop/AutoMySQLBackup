AutoMySQLBackup
===============
 A fork and further development of AutoMySQLBackup from sourceforge. http://sourceforge.net/projects/automysqlbackup/ 

You can find some original files from the sourceforge package. Some files are adjusted to my needs:
- support for MySQL 5.6 and MySQL 5.7
- support for login path (since MySQL 5.6.x a secure way to save your mysql credentials was implemented)
- adjusted the use of --ssl because it became depreated in MySQL 5.7. The parameter --ssl-mode=REQUIRED is used instead.

add login path
--------------
Per default this script uses the login path automysqldump.

```
mysql_config_editor set --login-path=automysqldump --host=localhost --user=root --password
```
After that command give your mysql root password and you're done. If you have another user to create the password with, feel free to edit the user parameter.


Have a try to make MySQL backups easily with this adjusted script. If you encounter any errors feel free to drop an issue. :)

For more Information check out http://www.sixhop.net/.
