#!/usr/bin/perl
#SBATCH -t 10:00:00
#SBATCH --mem=2G
#SBATCH -J seqSearch.pl

use strict;
use warnings;
use Getopt::Long qw(GetOptions);

my $user="$ENV{USER}"; # user name, please change it to your own name, i.e. 'jsmith'
my $outdir="";
######### Needed changes ended #################################

my $target="";
my $peppidir="/nfs/amino-home/ewbell/PEPPI";

GetOptions(
    "outdir=s" => \$outdir,
    "target=s" => \$target,
    "peppidir=s" => \$peppidir
    ) or die "Invalid arguments were passed into seqSearch\n";

#User-set parameters
my $bindir="$peppidir/bin";
my $libdir="$peppidir/lib";
my $stringdb="$libdir/STRING/STRINGseqsv11.db";
my $seqdb="$libdir/SEQ/100_psicquic.fasta";

#DO NOT CHANGE BENEATH THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING
#Processed parameters

my $randomTag=int(rand(1000000)); #This is to prevent multiple instances from deleting eachother's directories

print "Target: $target\n";

print `$bindir/blastp -query $outdir/$target/$target.fasta -db $stringdb -max_target_seqs 100 -outfmt "6 sseqid nident qlen slen" > $outdir/$target/$target.string`;
print `$bindir/blastp -query $outdir/$target/$target.fasta -db $seqdb -max_target_seqs 100 -evalue 1e10 -outfmt "6 sseqid nident qlen slen" > $outdir/$target/$target.seq`;
