# ABSTRACT: Notification by email
package Git::Code::Review::Notify::Email;

use strict;
use warnings;

use CLI::Helpers qw(:all);
use Git::Code::Review::Utilities qw(:all);
use MIME::Lite;
use File::Spec;
use Sys::Hostname qw(hostname);

# Globals
my %HEADERS = (
    'Sensitivity'           => 'company confidential',
    'X-Automation-Program'  => $0,
    'X-Automation-Function' => 'Git::Code::Review',
    'X-Automation-Server'   => hostname(),
);

sub send {
    shift @_ if ref $_[0] || $_[0] eq __PACKAGE__;
    my %config = @_;
    debug({color=>'magenta'}, "calling Git::Code::Review::Notify::Email::send");
    debug_var(\%config);

    # Need valid email properties
    unless( exists $config{to} && exists $config{from} ) {
        verbose({color=>'yellow'}, "Notify/Email - Insufficient email configuration, skipping.");
        return;
    }

    # Merge Headers
    foreach my $k (keys %HEADERS) {
        $config{headers} ||= {};
        $config{headers}->{$k} ||= $HEADERS{$k};
    }
    my $data = delete $config{message};
    die "Message empty" unless defined $data && length $data > 0;

    # Set urgency
    if($config{priority} eq 'high') {
        $config{headers}->{Importance} = 'High';
        $config{headers}->{Priority}   = 'urgent';
    }

    # Generate the email to send
    if( defined $data && length $data ) {
        debug("Evaluated template and received: ", $data);
        my $subject  = sprintf('%sGit::Code::Review %s %s=%s',
            $config{priority} eq 'high' ? '[CRITICAL] ' : '',
            uc $config{name},
            (exists $config{commit} ? "COMMIT" : "REPO"),
            (exists $config{commit} ? $config{commit}->{sha1} : gcr_origin('source')),
        );
        my $msg = MIME::Lite->new(
            From    => $config{from},
            To      => $config{to},
            Cc      => exists $config{cc} ? $config{cc} : [],
            Subject => $subject,
            Type    => exists $config{commit} ? 'multipart/mixed' : 'TEXT',
        );
        # Headers
        if (exists $config{headers} && ref $config{headers} eq 'HASH') {
            foreach my $k ( keys %{ $config{headers} }) {
                $msg->add($k => $config{headers}->{$k});
            }
        }

        # If this message is about a commit, let's attach it for clarity.
        if( exists $config{commit} && exists $config{commit}->{current_path} && -f $config{commit}->{current_path} ) {
            $msg->attach(
                Type => 'TEXT',
                Data => $data
            );
            $msg->attach(
                Type        => 'text/plain',
                Path        => $config{commit}->{current_path},
                Filename    => $config{commit}->{base},
                Disposition => 'attachment',
            );
        }
        else {
            $msg->data($data);
        }
        # Messaging
        if ( exists $ENV{GCR_NOTIFY_ENABLED} ){
            verbose({color=>'cyan'}, "Sending notification email.");
            my $rc = eval {
                $msg->send();
                1;
            };
            if($rc == 1) {
                output({color=>'green'}, "Notification email sent.");
            }
        }
        else {
            debug($msg->as_string);
            output({color=>'cyan',sticky=>1}, "Sending of email disabled, use --notify to enable.");
            verbose({indent=>1,color=>'green',sticky=>1}, "=> Email would go to: " . join(', ',
                    (ref $config{to} eq 'ARRAY' ? @{ $config{to} } : $config{to}),
                    (exists $config{cc} ? (ref $config{cc} eq 'ARRAY' ? @{ $config{cc} } : $config{cc}) : ()),
                )
            );
        }
    }
}

1;
