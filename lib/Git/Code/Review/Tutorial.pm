# ABSTRACT: How to work Git::Code::Review
package Git::Code::Review::Tutorial;

use strict;
use warnings;

1;
__END__
=head1 MOTIVATION

In agile environments, traditional code review and auditing mechanisms can
slow developer velocity.  In those environments, testing and monitoring may prove
more valuable then requiring other developers to approve code as part of the
deployment process.  Git::Code::Review was designed to be a parallel process to your
deployment pipeline.  It does not block commits, nor does it provide a way to.

Git::Code::Review is designed to select commits from a large code base.  It allows multiple
reviewers to coordinate audits of the code base, without creating barriers for getting code
live.  The current set of tools for code review/audit fail to provide a fast, simple, collaborative
approach to post-commit code review.  This tool is not for everyone, but fills a very small niche.

Ideal uses for Git::Code::Review:

    Auditing a new developer's commits

    Auditing a particular file or directory for changes

    Performing reviews for SOX or other compliance initiatives without alienating your developers.

If you're looking for a web interface with bling, this is not the tool for you.  If you do not or
cannot trust the code of your developers to go live without review, this tool is not for you.

=head1 HOWTO

Git::Code::Review requires you to use it with a repository with a remote B<origin> configured
on a branch B<master>.  This makes coordinating audits with multiple reviewers very easy.  The first step
is to setup the audit repository.

    $ mkdir /repos/financial-code-audit.git
    $ cd /repos/financial-code-audit.git
    $ git init --bare

You'll then need a working copy of the repository to start the audit:

    $ cd;
    $ git clone /repos/financial-code-audit.git

=head2 Initializing Git::Code::Review

With that configured, you'll need to initialize the Git::Code::Review details with the source repository.  This will
create a submodule in the audit repository for referencing objects, performing selections, and validating fixes.

    $ git-code-review init --repo https://github.com/user/repo.git --branch master

You do not need write access to the source repository, and you don't need to track master!  After the submodule is initialized and some metadata
computed and stored in the .code-review directory.  You're ready to start selecting commits.

=head2 Profiles

The default profile includes all commits in the repository.  It is possible to add profiles to divy up the reviews amongst individuals or teams.

To create a profile:

    $ git-code-review profile --add team_a

You will be given the opportunity to tune the selection criteria and the notification config for the new profile.  Configure git to automatically use
this profile for your audits:

    $ git config --global code-review.profile team_a

Now all commands will assume the newly configured "team_a" profile.

Editing profiles is simple:

    $ git-code-review profile --edit team_a

From there you can configure settings for the selection or notification.

=head2 Selection

To select commits we use the B<select> command.

    $ git-code-review select --since 2014-04-01 --number 15

This will prompt you for a reason, which you can optionally add on the command line:

    $ git-code-review select --since 2014-04-01 --number 15 --reason "April Code Review"

You can also specify which profile to use in the selection:

    $ git-code-review select --profile team_a --number 5 --reason "Team A audit!"

=head2 Picking a commit for review

When this is complete, you can begin the audit by picking a commit from the audit!

    $ git-code-review pick

You can also specify a date range for the commits to pick.  If you want a commit from June 2014:

    $ git code-review pick --since 2014-06-01 --until 2014-06-30

This will randomly select a commit from the list and present it to you in your $EDITOR.  The time spent in your
editor is tracked, and when you exit the editor, you will be prompted for the action you'd like to take:

    Action?

        1. (View) A file mentioned in the commit.
        2. (View) Commit again.
        3. [Approve] this commit.
        4. [Move] this commit to another profile.
        5. Raise a [concern] with this commit.
        6. [Resign] from this commit.
        7. Skip (just exits unlocking the commit.)

    Selection (1-7):

Pick also supports options to affect which commits to pick.  You can use the profile option to select commits in a particular
profile.  The 'default' profile is used otherwise:

    $ git-code-review pick --profile team_a

Pick defaults to using a randomized ordering for returning commits.  This is intended to avoid collisions if 6 developers are
reviewing code at the same time.  Not wanting to lock you into our madness, you can re-order the pick using the order which has
3 options:

=over

=item  B<asc> - By date ascending

=item  B<desc> - By date descending

=item  B<random> - The default, pick a random commit

To specify you'd like the earliest available commit, use:

    $ git-code-review pick --order asc

=back

=head3 Approval

This means the review of the code yielded no issues.  You will be asked why you want to approve this commit.  This
is critical data if you are going to use this process as a control in an audit.

    Why are you approving this commit?

        1. Calculations are all accurate.
        2. Cosmetic change only, no functional difference.
        3. Other (requires explanation)
        4. Changes are not in the bounds for the audit.

    Selection (1-4):

The choices should be self explanatory.  Selecting "other" will prompt you to explain yourself.  The rest of the
options will simply mark the commit as approved.  Performing a list will show you the state:

    $ git-code-review list
    -[ Commits in the Audit :: /Users/brad/tmp/repo/ ]-
        default   approved      2014-04-02      4464704ec55682a8768df3ce48c95f17e3081d2c        brad.lhotsky@booking.com
        default   review        2014-04-02      cbc8940419189daaf6067b5517141af20fe6bc50        brad.lhotsky@booking.com
        default   review        2014-04-02      ef93d4cc255b7977feb971a127de63423c1e82f9        brad.lhotsky@booking.com
        default   review        2014-04-10      35f7be02814f0b6b459994910b6657277f32579f        brad.lhotsky@booking.com
        default   review        2014-04-10      8a91765c642471093ecfa55e11b9448e60b744dc        brad.lhotsky@booking.com
        default   review        2014-04-10      af68e98711a8fad9fa9d4cfd7b2820e8d9dc90f9        brad.lhotsky@booking.com
        default   review        2014-04-10      e2d9a4f6da8285a6c4eb5b61448bb2a9e6f31951        brad.lhotsky@booking.com
    -[ Status  : approved:1, review:6 ]-
    -[ Profile : default:7 team_a:0 ]-
    -[ Source  : https://github.com/reyjrar/Git-Code-Review.git ]-

=head3 Concerns

Raising a concern with a commit will prompt you for a reason:

    Why are you raising a concern with this commit?

        1. Calculations are incorrect.
        2. Other
        3. Code is not clear, requires more information from the author.

    Selection (1-3): 1
    Explain: The sort order is backwards, descending is sort { $b <=> $a }.

Every commit you raise a concern with will require you to provide a comment.  This comment will be logged in the audit
history and optionally mailed to the commit author (TODO).  You can see the output here:

    $ git-code-review list
    -[ Commits in the Audit :: /Users/brad/tmp/repo/ ]-
        default   approved      2014-04-02      4464704ec55682a8768df3ce48c95f17e3081d2c        brad.lhotsky@booking.com
        default   concerns      2014-04-02      cbc8940419189daaf6067b5517141af20fe6bc50        brad.lhotsky@booking.com
        default   review        2014-04-02      ef93d4cc255b7977feb971a127de63423c1e82f9        brad.lhotsky@booking.com
        default   review        2014-04-10      35f7be02814f0b6b459994910b6657277f32579f        brad.lhotsky@booking.com
        default   review        2014-04-10      8a91765c642471093ecfa55e11b9448e60b744dc        brad.lhotsky@booking.com
        default   review        2014-04-10      af68e98711a8fad9fa9d4cfd7b2820e8d9dc90f9        brad.lhotsky@booking.com
        default   review        2014-04-10      e2d9a4f6da8285a6c4eb5b61448bb2a9e6f31951        brad.lhotsky@booking.com
    -[ Status approved:1, concerns:1, review:5 ]-
    -[ Profile : default:7 team_a:0 ]-
    -[ Source  : https://github.com/reyjrar/Git-Code-Review.git ]-

=head3 Resignation

There are certain times when you would like to resign from a commit that was picked for you.  You may not have experience
with the system, or you maybe the author.  In that case, resigning will prevent you from picking that commit again, while
leaving it available for other reviewers.

    Why are you resigning for this commit?

        1. I am the author.
        2. No experience with systems covered.
        3. other

    Selection (1-3):

You will then see that reflected in your list, while other reviewers will see the commit as ready to review:

    -[ Commits in the Audit :: /Users/brad/tmp/repo/ ]-
        default   approved      2014-04-02      4464704ec55682a8768df3ce48c95f17e3081d2c        brad.lhotsky@booking.com
        default   concerns      2014-04-02      cbc8940419189daaf6067b5517141af20fe6bc50        brad.lhotsky@booking.com
        default   resigned      2014-04-02      ef93d4cc255b7977feb971a127de63423c1e82f9        brad.lhotsky@booking.com
        default   review        2014-04-10      35f7be02814f0b6b459994910b6657277f32579f        brad.lhotsky@booking.com
        default   review        2014-04-10      8a91765c642471093ecfa55e11b9448e60b744dc        brad.lhotsky@booking.com
        default   review        2014-04-10      af68e98711a8fad9fa9d4cfd7b2820e8d9dc90f9        brad.lhotsky@booking.com
        default   review        2014-04-10      e2d9a4f6da8285a6c4eb5b61448bb2a9e6f31951        brad.lhotsky@booking.com
    -[ Status approved:1, concerns:1, resigned:1, review:4 ]-
    -[ Profile : default:7 team_a:0 ]-
    -[ Source  : https://github.com/reyjrar/Git-Code-Review.git ]-

=head3 Move

If you have more than 1 profile enabled, reviewers have the ability to move commits from one profile to another.  This
may happen if path matches overlap or if multiple teams work on code.  If you know no one else in your team will be able
to review the commit, use the 'move' command instead of the 'resign' command.

=head3 Skip

You can use the skip command to free your lock on that commit.  The lock/skip process is logged, but will allow you to free
the commit for another time or another author.

