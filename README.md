# imapsieve_copy for Mailcow


## Asynchronous ham/spam learning for mailcow-dovecot

In a normal mailcow installation, spam/ham learning as a result of user actions 
is done in-line. This slows down moving mails to and from the Junk folders. This 
causes issues with timeouts on clients, which can then cause mails to be 
re-copied which results in possible infinite mail duplications, and a poor user 
experience.

The imapsieve_copy tool copies these emails to a separate directory in your 
vmail spool for later processing by the scan_reported_mail.sh script

The imapsieve_copy is inserted into the sieve processing by modififying the 
normal report-spam and report-ham sieves. 

The scan_reported_mails.sh then calls the normal rspamd-pipe-ham and 
rspamd-pipe-spam tools, respectively, when run. This script is written as a 
singleton, ie if a second invocation is made when the first is still in process, 
then it will immediately exit so as to not conflict with the first.

When scan_reported_mails.sh is run it will move all currently reported mails 
into its processing directory, process them, and then cleanup. The next time it 
is run, by default every minute, then it will process all new messages which 
have been reported in the meantime.

This version of imapsieve_copy was developed by [Stuart Espey](mailto:stux+imapsieve_copy%20at%20mactrix.com), 
based on the original version by [Zhang Huangbin](zhb%20at%20iredmail.org),

Original version: [IRedMail Imapsieve](https://docs.iredmail.org/dovecot.imapsieve.html)


## Installation

Extract the imapsieve_copy archive into your mailcow data/conf/dovecot 
directory, then ensure that the permissions are correct:

```
:/opt/mailcow-dockerized# ls -al data/conf/dovecot/imapsieve_copy/
total 28
drwxr-xr-x 2 root root 4096 Aug 12 13:05 .
drwxr-xr-x 6 root root 4096 Aug 12 12:31 ..
-rwxr-xr-x 1 root root  895 Aug 12 12:44 imapsieve_copy
-rw-r--r-- 1 root root 1024 Aug 12 12:58 README.md
-rw-r--r-- 1 root root  573 Aug 12 12:15 report-ham.sieve
-rw-r--r-- 1 root root  471 Aug 12 12:16 report-spam.sieve
-rwxr-xr-x 1 root root 3137 Aug 12 12:06 scan_reported_mails.sh
```

Then add the following to your docker-compose.override.yml:


```
  dovecot-mailcow:
    volumes:
      # install imapsieve_copy
      - ./data/conf/dovecot/imapsieve_copy/report-ham.sieve:/usr/lib/dovecot/sieve/report-ham.sieve
      - ./data/conf/dovecot/imapsieve_copy/report-spam.sieve:/usr/lib/dovecot/sieve/report-spam.sieve
      - ./data/conf/dovecot/imapsieve_copy/imapsieve_copy:/usr/lib/dovecot/sieve/imapsieve_copy
      - ./data/conf/dovecot/imapsieve_copy/scan_reported_mails.sh:/usr/lib/dovecot/scan_reported_mails.sh

    labels:
      # and schedule it
      - "ofelia.job-exec.dovecot_scan_reported_emails.schedule=@every 1m"
      - "ofelia.job-exec.dovecot_scan_reported_emails.command=/usr/lib/dovecot/scan_reported_mails.sh"
      - "ofelia.job-exec.dovecot_scan_reported_emails.tty=false"
      - "ofelia.job-exec.dovecot_scan_reported_emails.no-overlap=true"

```

This will mount the imapsieve_copy components over the top of the original imap 
sieve components in mailcow. 

You will need to restart dovecot and ofelia. Dovecot needs a full restart to 
re-compile the sieves. Ofelia needs a restart to install the job scheduler which 
will scan the mails.

```
docker-compose up -d ; docker-compose restart ofelia-mailcow
```

## Dovecot.conf changes

No changes are actually needed, but the original author suggests adding `APPEND` 
to the `imapsieve_mailbox1_causes` property, as this should catch Outlook moves. 
[Auto learn spam/ham with Dovecot and Outlook](https://forum.iredmail.org/topic15464-auto-learn-spamham-with-dovecot-and-outlook-20132016.html)

```
 # From elsewhere to Spam folder
  imapsieve_mailbox1_name = Junk
  imapsieve_mailbox1_causes = COPY APPEND
  imapsieve_mailbox1_before = file:/usr/lib/dovecot/sieve/report-spam.sieve
 # END
```

## Testing

If you want, you can execute the scan_reported_mails.sh anyway you want, 
including manually while testing.

I found it useful to modify scan_reported_mails.sh to utilize different spam/ham 
incoming directories, and to use `cp -at` instead of `mv -t` while testing, as 
this prevented removal of incoming spam/ham.

## Logs

scan_reported_mails.sh outputs basic information to the ofelia log, and more 
detailed information including rspamd status to the dovecot log imapsieve_copy 
logs to the dovecot log when an email is copied.

## Directories

By default imapsieve_copy creates an `imapsieve_copy` directory in the root of 
your vmail spool with `ham` and `spam` subdirectories. scan_reported_mails.sh
creates a temporary `processing` directory in this `imapsieve_copy` directory, 
with `spam` and `ham` subdirectories. These directories are not on the /tmp fs
to prevent losing messages in the event of a restart.

## Revision History
2021-08-12 Initial Version
