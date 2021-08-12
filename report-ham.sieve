require ["vnd.dovecot.pipe", "copy", "imapsieve", "environment", "variables"];

if environment :matches "imap.mailbox" "*" {
  set "mailbox" "${1}";
}

# not ham if we moved from junk to trash.
# additional support for courier migrated INBOX. prefixes
if string :matches "${mailbox}" ["INBOX.Trash", "Trash"] {
  stop;
}

#bypass inline learning
#pipe :copy "rspamd-pipe-ham";

# copied emails are prefixed with user
if environment :matches "imap.user" "*" {
    set "username" "${1}";
}

# copy to /var/vmail/imapsieve_copy/ham
pipe :copy "imapsieve_copy" [ "${username}", "ham" ];
