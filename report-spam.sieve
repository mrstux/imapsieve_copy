require ["vnd.dovecot.pipe", "copy", "imap4flags", "environment", "variables", "imapsieve"];

#bypass inline learning
#pipe :copy "rspamd-pipe-spam";

# no one wants to see unread counts on junk folders after moving unread mail to junk folders.
addflag "\\Seen";

# copied emails are prefixed with user
if environment :matches "imap.user" "*" {
    set "username" "${1}";
}

# copy to /var/vmail/imapsieve_copy/spam
pipe :copy "imapsieve_copy" [ "${username}", "spam" ];
