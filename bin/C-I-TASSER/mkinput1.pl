#!/usr/bin/perl
use Math::Trig;
use Getopt::Long qw(GetOptions);

#################################################################
# Disclaimer: C-I-TASSER is the software developed at Zhang Lab #
# at DCMB, University of Michigan. No any part of this package  #
# could be released outside the Zhang Lab without permission    #
# from the orginal authors. Violation of this rule may result   #
# in lawful consequences.                                       #
#################################################################

######## What this program does? ###############################
#
# This program generates most input files for C-I-TASSER.
#   input files:
#	seq.fasta  	(query sequence in FASTA format)
#   output files:
#	seq.seq  	(query sequence in FASTA format)
#	seq.dat		(predicted secondary structure)
#	seq.ss		(predicted secondary structure)
#	rmsinp		(length file)
#	exp.dat		(predicted solvant assessibility)
#	pair3.dat	(general pair-wise contact potential)
#	pair1.dat	(general pair-wise contact potential)
#       init.XXX        (threading templates from XXX, eg, XXX=hhpred)
#       XXX.dat         (contact  prediction from XXX, eg, XXX=respre)
#
#  Tips: All the intermediate files are deposited at 
#       /nfs/amino-home/zhng/C-I-TASSER/version_2013_03_20/test/record
#       When you find some of the input files fail to generate, you can rerun 
#       the specific jobs rather the entire mkinput.pl, e.g. if 'init.BBB' 
#       is not generated, you can just rerun 
#       /nfs/amino-home/zhng/C-I-TASSER/version_2013_03_20/test/record/BBB15_2rjiA
#       
################################################################


######## ALL these variables MUST be changed before run ###############
$ENV{'PATH'}="/nfs/amino-home/zhanglabs/bin:$ENV{'PATH'}";

$user="$ENV{USER}"; # user name, please change it to your own name, i.e. 'jsmith'
$outdir="";
$bindir="/nfs/amino-home/ewbell/PEPPI/bin/C-I-TASSER";
$njobmax=1; #maximum number of jobs submitted by you
$Q="batch"; #what queue you want to use to submit your jobs
$oj="1"; #flag number for different runs, useful when you run multiple jobs for same protein
#$svmseq="no";  # run I-TASSER
######### Needed changes ended #################################

my $s="";
my $bindir="/nfs/amino-home/ewbell/PEPPI/bin/C-I-TASSER";
my $benchflag=0;
my $domaindiv=0;

GetOptions(
    "benchmark" => \$benchflag,
    "domains" => \$domaindiv,
    "outdir=s" => \$outdir,
    "target=s" => \$s,
    "jobmax=i" => \$njobmax
    ) or die "Invalid arguments were passed into C-I-TASSER";

my $run=($benchflag) ? "benchmark" : "real";
$outdir="$outdir/fasta";

### Please do not change files below unless you know what you are doing #####
#
# step-0: prepare 'seq.txt' from 'seq.fasta' (local)
# Step-1: make 'seq.dat', 'rmsinp' by runpsipred.pl (qsub)
# Step-2: make 'exp.dat'   (qsub)
# Step-3: make 'pair3.dat' and 'pair1.dat' (qsub)
# step-4: run threading.pl (qsub)
# step-5: run contact.pl   (qsub)
#
# The log files are in $outdir/record if you want to debug your files

$lib="/nfs/amino-library";

################# directory assignment #############################
$u=substr($user,0,1);
$librarydir="$lib"; #principle library, should not be changed
$recorddir="$outdir/record"; #for record all log files and intermiddiate job files
`mkdir -p $recorddir`;

@TT=qw(
       HHW

       SPX
       FF3
       MUS
       RAP3
       HHP

       JJJb
       IIIe
       VVV
       BBB
       WWW

       RRR3
       PRC
       ); #threading programs
# when you update @TT, please remember to update type.pl

#HHW-HHpred (modified)
#SPX-Sparkx
#FF3-FFAS3D
#RAP3-Raptor
#HHP-HHpred (modified)

#MUS-MUSTER
#JJJb-PPI (unpublished)
#IIIe-HHpred_local
#VVV--SP3
#RRR3-FFAS

#WWW--PPI (unpublished)
#BBB--PROSPECT2
#PRC--PRC

#------following programs does not need seq.dat:
#SPX
#HHP
#IIIe 
#IIIj
#UUU
#VVV
#CCC
#RAP3
#RRR3
#pgen
#PRC
#------following need seq.dat but will generate on their own:
#WWW   need blast but generate by itself
#MUS   need blast and seq.dat but generate by itself
#JJJb  need seq.dat.ss (generated by its own)
#------following will wait for the master program to generate seq.dat:
#BBB   need seq.dat.ss (waiting)
#GGGd  need seq.dat (waiting)
#NNNd  need seq.dat (waiting)
#RRR6  need seq.dat (waiting)
#HHWmod  need seq.dat (waiting)

#### parameters #########////
if($run eq "benchmark"){
    $id_cut=0.3;   #cut-off  of sequence idendity
}else{
    $id_cut=10;   #cut-off  of sequence idendity
}
$n_temp=20;     #number of templates
$o=""; #will generate init$o.MUS

$qzy=`$bindir/qzy`; #script for statistics of all jobs


$datadir="$outdir/$s";
$datadir1="$outdir";
if(!-s "$datadir/seq.fasta"){
    printf "error: without $datadir/seq.fasta\n";
    goto pos1;
}

############ step-0: convert 'seq.fasta' to 'seq.txt' with standard format ####
open(seqtxt,"$datadir/seq.fasta");
$sequence="";
while($line=<seqtxt>){
    goto pos1 if($line=~/^>/);
    if($line=~/(\S+)/){
	$sequence .=$1;
    }
  pos1:;
}
close(seqtxt);
open(fasta,">$datadir/seq.txt");
printf fasta "> $s\n";
$Lch=length $sequence;
for($i=1;$i<=$Lch;$i++){
    $seq1=substr($sequence,$i-1,1);
    $seq{$i}=$ts{$seq1};
    printf fasta "$seq1";
    if(int($i/60)*60==$i){
	printf fasta "\n";
    }
}
printf fasta "\n";
close(fasta);

### check number of my submitted jobs to decide whether I can submit new jobs ##
 pos50:;
$jobs=`$bindir/jobcounter.pl $user`;
if($jobs=~/njobuser=\s+(\d+)\s+njoball=\s+(\d+)/){
    $njobuser=$1;
    $njoball=$2;
}
if($njobuser+scalar(@TT) > $njobmax){
    printf "$njobuser > $njobmax, let's wait 2 minutes\n";
    sleep (120);
    goto pos50;
}

#@@@@@@@@@@@@@@@@ step-1: generate 'seq.dat' and seq.dat.ss' @@@@@@@@@@@@@@@@@@@@@@
$tmp1="$datadir/seq.dat";
$tmp2="$datadir/rmsinp";
if(-s "$tmp1" >50 && -s "$tmp2" >5){
    open(tmp,"$tmp1");
    $line=<tmp>;
    close(tmp);
    if($line=~/\d+/){
	open(tmp,"$tmp2");
	$line=<tmp>;
	close(tmp);
	if($line=~/(\d+)/){
	    goto pos1a; #files are done
	}
    }
    }
$mod=`cat $bindir/mkseqmod`;
###
$tag="mkseq$o$u$oj\_$s"; # unique name
$jobname="$recorddir/$tag";
$errfile="$recorddir/err_$tag";
$outfile="$recorddir/out_$tag";
$walltime="walltime=10:00:00,mem=3000mb";
###
$mod1=$mod;
$mod1=~s/\!ERRFILE\!/$errfile/mg;
$mod1=~s/\!OUTFILE\!/$outfile/mg;
$mod1=~s/\!WALLTIME\!/$walltime/mg;
$mod1=~s/\!NODE\!/$node/mg;
$mod1=~s/\!TAG\!/$tag/mg;
$mod1=~s/\!USER\!/$user/mg;
$mod1=~s/\!DATADIR\!/$datadir/mg;
$mod1=~s/\!LIBRARYDIR\!/$librarydir/mg;
open(job,">$jobname");
print job "$mod1\n";
close(job);
`chmod a+x $jobname`;

######### check whether the job is running ##########
if($jobname=~/record\/(\S+)/){
    $jobname1=$1;
    if($qzy=~/$jobname1/){
	printf "$jobname1 is running, neglect the job\n";
	goto pos1a;
    }
}

########## submit my job ##############
 pos41:;
$bsub=`qsub -q $Q $jobname`;
chomp($bsub);
if(length $bsub ==0){
    sleep(20);
    goto pos41;
}
$date=`/bin/date`;
chomp($date);
open(note,">>$recorddir/note.txt");
print note "$jobname\t at $date $bsub\n";
close(note);
printf "$jobname was submitted.\n";
 pos1a:;

#@@@@@@@@@@@@@@@@ step-3: generate 'pair3.dat' and 'pair1.dat' @@@@@@@@@@@@@@@@@@@@@@
$tmp1="$datadir/pair1.dat";
$tmp2="$datadir/pair3.dat";
if(-s "$tmp1" >50 && -s "$tmp2" >5){
    open(tmp,"$tmp1");
    $line=<tmp>;
    close(tmp);
    if($line=~/\d+\s+\S+/){
	open(tmp,"$tmp2");
	$line=<tmp>;
	close(tmp);
	if($line=~/(\d+)\s+\S+/){
	    goto pos1c; #files are done
	}
    }
}
$mod=`cat $bindir/mkpairmod99`;
###
$tag="mkp$o$u$oj\_$s"; # unique name
$jobname="$recorddir/$tag";
$errfile="$recorddir/err_$tag";
$outfile="$recorddir/out_$tag";
$walltime="walltime=30:00:00,mem=3000mb";
###
$mod1=$mod;
$mod1=~s/\!TAG\!/$tag/mg;
$mod1=~s/\!USER\!/$user/mg;
$mod1=~s/\!S\!/$s/mg;
$mod1=~s/\!INPUTDIR\!/$datadir/mg;
$mod1=~s/\!RUN\!/$run/mg;
$mod1=~s/\!BINDIR\!/$bindir/mg;
open(job,">$jobname");
print job "$mod1\n";
close(job);
`chmod a+x $jobname`;

######### check whether the job is running ##########
if($jobname=~/record\/(\S+)/){
    $jobname1=$1;
    if($qzy=~/$jobname1/){
	printf "$jobname1 is running, neglect the job\n";
	goto pos1c;
    }
}

 pos43:;
$bsub=`qsub -q $Q -e $errfile -o $outfile -l $walltime $jobname`;
chomp($bsub);
if(length $bsub ==0){
    sleep(20);
    goto pos43;
}
$date=`/bin/date`;
chomp($date);
open(note,">>$recorddir/note.txt");
print note "$jobname\t at $date $bsub\n";
close(note);
printf "$jobname was submitted.\n";
 pos1c:;

#@@@@@@@@@@@@@@@@ step-4: run LOMETS threading @@@@@@@@@@@@@@@@@@@@@@

#### dirs ###############
$workdir=$datadir;
$data_dir=$datadir;
$lib_dir=$librarydir; 

##### circle:
foreach $T(@TT){
    $tmp="$datadir/init.$T";
    if(!-s "$tmp"){
	$tag="$o$u$T$oj\_$s"; # unique name
	$jobmod="$T"."mod";
	if($T eq "RRR6" || $T=~/RAP/ || $T=~/HHW/ || $T=~/CET/ || $T=~/MAP/){ # need multiple nodes or high memory
	    $walltime="walltime=40:00:00,mem=15000mb"; #<>=2.5h; [1.5,5.8]
	    if($Lch>1000){
		$walltime="walltime=40:00:00,mem=25000mb"; #<>=2.5h; [1.5,5.8]
	    }
	}else{
	    $walltime="walltime=40:00:00,mem=4000mb";
	    if($Lch>1000){
		$walltime="walltime=40:00:00,mem=10000mb"; #<>=2.5h; [1.5,5.8]
	    }
	}
	&submitjob($workdir,$recorddir,$lib_dir,$data_dir,$bindir,
		   $tag,$jobmod,$walltime,$id_cut,$n_temp,
		   $s,$o,$Q,$user,$run,$outdir);
    }
}

#####//////////////
sub submitjob{
    my($workdir,$recorddir,$lib_dir,$data_dir,$bindir,
       $tag,$jobmod,$walltime,$id_cut,$n_temp,
       $s,$o,$Q,$user,$run,$outdir)=@_;
    
    ###
    $jobname="$recorddir/$tag";
    $runjobname="$recorddir/$tag\_run";
    $errfile="$recorddir/err_$tag";
    $outfile="$recorddir/out_$tag";
    $node="nodes=1:ppn=1";
    ###
    #------- runjobname ------>
    $mod=`cat $bindir/runjobmod`;
    $mod=~s/\!ERRFILE\!/$errfile/mg;
    $mod=~s/\!OUTFILE\!/$outfile/mg;
    $mod=~s/\!WALLTIME\!/$walltime/mg;
    $mod=~s/\!RECORDDIR\!/$recorddir/mg;
    $mod=~s/\!JOBNAME\!/$jobname/mg;
    $mod=~s/\!NODE\!/$node/mg;
    $mod=~s/\!TAG\!/$tag/mg;
    open(runjob,">$runjobname");
    print runjob "$mod\n";
    close(runjob);
    `chmod a+x $runjobname`;
    ###
    #------- jobname ------>
    $mod=`cat $bindir/$jobmod`;
    $mod=~s/\!S\!/$s/mg;
    $mod=~s/\!O\!/$o/mg;
    $mod=~s/\!ID_CUT\!/$id_cut/mg;
    $mod=~s/\!N_TEMP\!/$n_temp/mg;
    $mod=~s/\!DATA_DIR\!/$outdir/mg;
    $mod=~s/\!DATADIR\!/$outdir/mg;
    $mod=~s/\!LIB_DIR\!/$lib_dir/mg;
    $mod=~s/\!TAG\!/$tag/mg;
    $mod=~s/\!USER\!/$user/mg;
    $mod=~s/\!RUN\!/$run/mg;
    open(job,">$jobname");
    print job "$mod\n";
    close(job);
    `chmod a+x $jobname`;
    
    ######### check whether the job is running ##########
    if($jobname=~/record\/(\S+)/){
	$jobname1=$1;
	if($qzy=~/$jobname1/){
	    printf "$jobname1 is running, neglect the job\n";
	    goto pos1d;
	}
    }
    
    #-------job submision --------------->
  pos44:;
    $bsub=`qsub -q $Q $runjobname`;
    chomp($bsub);
    if(length $bsub ==0){
	sleep(20);
	goto pos44;
    }
    $date=`/bin/date`;
    chomp($date);
    open(note,">>$recorddir/note.txt");
    print note "$jobname\t at $date $bsub\n";
    close(note);
    print "$jobname was submitted.\n";
    
  pos1d:;
}

#Submit ThreaDom job
if ($domaindiv){

}

 pos1:;

exit();
