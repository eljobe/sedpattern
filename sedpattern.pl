#!/usr/bin/perl -w

###############################################################################
#      Script: sedpattern.pl
#      Author: Pepper Lebeck-Jobe (eljobe@gmail.com)
#     Version: 1.2
#
# Version History:
#     1.0    Initial Coding               2007-02-19
#     1.1    Added Comments               2007-02-20
#            Removed the %hits hash
#     1.2    Only look at s words         2016-06-07
#            Only look at words length 5
#            Skip noop words like sununu
#
# Description:
#
#   The purpose of this script is to search through a word-list and
# find any word which could be used as a replacement command in sed,
# and then process that same word-list a second time and find all word
# pairs which could be converted to and from using the first word as
# the replacement command with sed.
#
#
# Motivation:
#
#   One day I found out that you can use any character as the
# delimiter in a sed expression. This is an important feature of sed
# to know.  For example, if you wanted to change the names of all
# 'index.html' files that lived in some directory called 'home' to be
# called 'home.html' and live in a 'site' directory, you might need to
# use the following sed statement as one part of your shell script:
#
#     sed s/home\/index/site\/home/
#
#   But, that is a bit difficult to read.  All of the escaping of the
# delimitting character makes it difficult to read the pattern.  See
# how much easier it is to read if you use the '@' character as the
# delimiter?
#
#     sed s@home/index@site/home@
#
#   So, this feature is pretty handy.  But, it could be abused!  And
# that is where the fun began.  I started thinking, "I wonder if there
# are any regular, English words which are generally of the pattern
# sxfooxbarx?"  It didn't take me to long to realize the the word
# "statement" matched the pattern.  The word "statement" could be used
# as the argument for the sed command, and it would also have the
# delicious coincidence of being easily mistakeable as a generic name
# for a more specific arguement to sed.
#
#   Now I just needed two words that were the same if you replaced the
# first 'a' in the word with 'emen'.  Again, it didn't take me long to
# stumble onto "cat" and "cement".  This meant that the next day at
# work I could ask my co-workers this brain teaser:
#
#     "How do you turn a cat into cement using a sed statement?"
#
#   It was a blast.  I got tons of odd looks and curiosity.  I ended
# up writing the following on probably 6 different white-boards:
#
#     $> echo "cat" | sed statement
#     cement
#
#   One of the most common reactions was exactly what I was looking
# for: "Well, yeah, so you want me to tell you what to put in place of
# statement?"  And then I got to say, "No, I just want you to open up
# a terminal and type exactly what I have written on your board."
#
#   One guy verbally reacted, "Huuh?!? But ... No Way!"  He figured it
# out about a minute later, but that initial reaction was priceless.
#
#   So, after I got over the initial thrill of the puzzle, I decided
# that it would be really cool to write a program that would search
# through all the words in the english language and create a list of
# s-words which could be used as the argument to a sed statement and
# also print out all of the word pairs which could represent the to
# and from sides of the equation.  So, I wrote this script.
#
#
# Design Decisions:
#
#   I decided that I was only really interested in words which matched
# this pattern: sxfooxbarx
# where: x   = a single character
#        foo = some string of length > 0
#        bar = some string of length > 0
#
#   It is true that these requirements are not the same as the general
# requirements for a valid sed expression, but they make for more
# interesting output, and keep me from having to deal with the added
# complexity of handling all of the possible trailing modifiers
# available in sed expressions like 'g' or 'p'
#
#   The main data structure of this program is dynamically populated,
# so it is not clear from its declaration what it is going to hold.
# The data structure in question is the %words hash.  Here is its
# internal structure:
#
#     %words {
#         $word => \@ {
#             $search,
#             $replace,
#             \% {
#                 $hit_pat => $hit_cnt
# 	      }
#         }
#     }
#
#   Each element of the internal structure is explained like this:
#     %words    = The top level hash
#     $word     = The key which points to an anonymous array
#                 reference
#     $search   = The pattern that will be searched for in the word
#                 list
#     $repace   = The replacement string for the pattern
#     \%        = An anonymous hash reference
#     $hit_pat  = The pattern which matched either search or replace
#     $hit_cnt  = The number of times the pattern hit
#
#   For the word "statement", the program eventually has a section of
# its data which looks like this:
#     $word     = "statement"
#     $search   = "a"
#     $replace  = "emen"
#     $hit_pat  = "c!t"
#     $hit_cnt  = 2 (one for "cat" and one for "cement")
#
#   To list out all of the words which can be used and the word-pairs
# which they transform from and to, you really only need to iterate
# over the keys in the hash and find any hit patterns that have a hit
# count of two and print out the hit pattern with the search string
# substituted for the '!' and then the replace string substituted for
# the '!'
#
#
# Inputs:
#
#   The main input to this program is a one-word per line word-list.
#   Each line is assumed to match /^\w*$/
#
#   TODO: Better argument processing.
#         Rewrite to be able to use piped input.
#
# Output:
#
#   One line with three fields per hit pattern with a hit count of 2
# printed to STDOUT.
#
#   For example:
#   statement              cat                    cement
#
###############################################################################
use strict;
use FileHandle;

# BEGIN MAIN BODY

# Read the first argument as the filename
my $wordlist = shift;
# Create a FileHandle object for more readable code
my $fh = new FileHandle;
my %words;
my $debug = 0; # TODO: Make this a flag to the program.

# Iterate over the word-list looking for the sed pattern.

print "Building pattern list ...\n" if $debug;
$fh->open("<".$wordlist) or die "Failed to open $wordlist\n";
while (<$fh>) {
    chomp;
    my @chars = split(//);

    if ($chars[0] ne "s" || scalar(@chars) < 5) {
	# The word cannot be a sed pattern.
	next;
    }

    my $x = $chars[1];
    my $sed_pattern = "^s".$x."([^".$x."]+".$x."){2,2}".'$';

    # The definition of this sed pattern warrents explaination.
    # Say the word in our list is "statement":
    # $x = 't';
    # $sed_pattern = '^st([^t]+t){2,2}$';
    #
    # Creating the sed pattern in this manner means we will only match
    # words with the following criteria:
    #
    #  1. The word starts with an 's'
    #  2. The second character of the word is also the last character.
    #  3. The second character of the word appears exactly one other
    #     time in the word.
    #  4. There is at least one non-second character-character between
    #     each occurance of the second character.
    #
    # This is exactly the criteria for which we want to search.

    if (/$sed_pattern/) {
        print $_."\n" if $debug;
        my @parts = split($x);
	if ($parts[1] eq $parts[2]) {
	    # We don't want to use a word like "sununu"
	    next;
	}
        my $word = $_;
        # The anonymous array reference with $search and $replace
        my @patterns = ($parts[1], $parts[2]);
        print "$word => $parts[1] $parts[2]\n" if $debug;
        $words{$word} = \@patterns;
    }
}
$fh->close();

# Iterate over the file a second time building up the individual
# hit_pattern hashes.  This is the most complicated part of the
# program.  What you need to keep in mind is that we are only going
# through the word-list one time.
#
# As we go, through, we are seeing if a particular word matches the
# $search part of our sed word, and then the $replace part of our sed
# word.  And in either case, storing the part of the word that DOESN'T
# match the pattern into a hash.  This is most easily understood by
# example.
#
# Imagine this very brief word-list:
#    bat
#    cat
#    cement
#    statement
#
# On the first pass through, we find that "statement" matches our sed
# pattern.  And that $search is "a" and $replace is "emen"
#
# On our second time through (represented by this while loop) ...
# 
# "bat" matches the $search so we add one to the hash key "b!t" == 1
# "cat" matches the $replace so we add one to the hash key "c!t" == 1
# "cement" matches the $search so we add one to the hash key "c!t" == 2
# "statement" matches the $search so we add one to the hash key "st!tement" == 1
# "statement" matches the $replace so we add one to the hash key "stat!t" ==1
#
# In the last execution loop, we will search only for keys that have
# the value of 2. Which means that the word which holds the hit
# pattern can be used as an argument to sed to transform cat (the word
# which is created by replacing the '!' in the hit pattern with the
# $search) into cement (the word which is created by replacing the '!'
# in the hit pattern with the $replace.)
#
# Little comments referencing this example are sprinkled throughout
# this loop to clarify. (Look for "# EX:")

print "Searching for matches ...\n" if $debug;
$fh->open("<".$wordlist) or die "Failed to open $wordlist\n";
while (<$fh>) {
    chomp;
    my $line = $_;                             # EX: $line      = cat
    for my $word ( sort (keys %words) ) {      # EX: $word      = statement
        my $contents_ref = $words{$word};  # References the array
        my $search = ${$contents_ref}[0];      # EX: $search    = a
        my $replace = ${$contents_ref}[1];     # EX: $replace   = emen
        $_ = $line;
        if (s/$search/!/) {                    # EX: cat s/a/!/ = c!t
            # Derefferences the array reference then the hash
            # reference which is the third array element.
	    ${ ${$contents_ref}[2] }{$_} += 1; # EX: Add one to c!t
	}
        $_ = $line;
        if (s/$replace/!/) {                   # EX: cat s/emen/!/ = 0
            # Derefferences the array reference then the hash
            # reference which is the third array element.
	    ${ ${$contents_ref}[2] }{$_} += 1; # EX: Don't execute
	}
    }   
}
$fh->close();

# Just setting some variables up for use in the format of the output.
my ($word, $search, $replace);

# This just makes prettier output for the "write;" line below.
format =
@<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<
$word,                 $search,               $replace
.

# Iterate over all of the word_hits for all of the sed_pattern words
# and print out the ones that have exactly 2 hits.
for $word ( sort (keys %words) ) {                # EX: $word    = statement
    my %word_hits = %{ ${$words{$word}}[2] };
    for my $hit_pat (sort (keys %word_hits) ) {   # EX: $hit_pat = c!t
        if ($word_hits{$hit_pat} == 2) {
	    $search = ${$words{$word}}[0];        # EX: $search  = a
	    $replace = ${$words{$word}}[1];       # EX: $replace = emen
            $_ = $hit_pat;
            s/!/$search/;                         # EX: c!t -> cat
            $search = $_;                         # EX: $search  = cat
	    $_ = $hit_pat;
            s/!/$replace/;                        # EX: c!t -> cement
            $replace = $_;                        # EX: $replace = cement
            write;                                # EX: statement cat cement
	}
    }
}
# END MAIN BODY
