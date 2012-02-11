
echo Doing regression tests with test archive $TESTA....

function printop { op=$1; echo " * $op"; };
function failure { echo "FAILURE in: $op"; failed=1; };
comploc=`pwd`/dircompare
function dircomp { export d1=$1; export d2=$2; export cmpflag=$3; bash -c $comploc; };

# do actual regression test

wd=`pwd`

source regtest.clean

if [ "$OLDAF" != "" ]; then

printop "unpack test archive to t1/ with old afio"
mkdir t1
cd t1
if ! $OLDAF -iZ $TESTA; then
 failure
fi
cd $wd


if [ -d $OLDTESTD ]; then
 printop "compare test archive with unpacked old test archive"
 if ! dircomp $OLDTESTD t1/afiot; then
  failure
 fi
fi

fi


printop "unpack test archive to t2/ with new afio"
mkdir t2
cd t2
if ! $NEWAF -iZ $TESTA; then
 failure
fi
cd $wd

if [ $ERRORINJECT = 1 ]; then
echo adding some errors to self-test the regression test
echo > t1/afiot/jbtdfj
echo > t2/afiot/ergergeg
echo >>t2/afiot/files/b2
chmod 222 t2/afiot/files/b3
fi

if [ "$OLDAF" != "" ]; then
printop "compare test archive trees that were unpacked by new and old afio"
if ! dircomp t1 t2; then
 failure
fi
fi


if [ -f $TESTTAR ]; then
 printop "untar tarred version of test archive into t4/ (the tarred version does not contain future-dated file and socket file)"
 mkdir t4
 cd t4
 if ! gunzip -c $TESTTAR | tar xf -; then
  failure
 fi
 printop "compare unpacked tar archive with newly unpacked test archive"
 cd $wd
 if ! dircomp t4/afiot t2/afiot nouid; then
  failure
 fi
fi


printop "verify unpacked test archive with new afio";
cd t2
if ! $NEWAF -rZ $TESTA; then
 failure
fi
cd $wd

# --- now we switch to packing experiments on the test tree
# (with the new dates on the dirs etc)

printop "pack test tree with new afio again"
cd t2
if ! $NEWAF -Zt $TESTA | sort | $NEWAF -oZ ../t2.afn; then
 failure
fi
cd $wd

if [ "$OLDAF" != "" ]; then

printop "pack test tree with old afio again"
cd t2
if ! $NEWAF -Zt $TESTA | sort | $OLDAF -oZ ../t2.afo; then
 failure
fi
cd $wd

printop "check if archive files produced by new and old afio are identical"
if ! cmp t2.afo t2.afn; then
 failure
fi
fi

printop "pack test tree with new afio using -f and some other strange options"
cd t2
if ! $NEWAF -Zt $TESTA | sort | tr '\n' '\0' | $NEWAF -oZ -f -s 10m -0 ../t2.afnb; then
 failure
fi
cd $wd

printop "check if archive file produced using -f and other strange options is same"
if ! cmp t2.afn t2.afnb; then
 failure
fi

if [ "$OLDAF" != "" ]; then
printop "verify newly packed archive with old afio"
cd t2
if ! $OLDAF -rvZ ../t2.afn >../t2.afov; then
 failure
fi
cd $wd
fi

printop "verify newly packed archive with new afio"
cd t2
if ! $NEWAF -rvZ ../t2.afn >../t2.afnv; then
 failure
fi
cd $wd

if [ "$OLDAF" != "" ]; then
printop "compare verify operation -v outputs of new and old afio"
if ! cmp t2.afov t2.afnv; then
 diff -U 0 t2.afov t2.afnv
 failure
fi
fi

printop "try to install newly packed archive into t3/ with new afio"
mkdir t3
cd t3
if ! $NEWAF -iZ ../t2.afn; then
 failure
fi
cd $wd

printop "check if tree is identical after packing and unpacking with new afio"
if ! dircomp t2 t3; then
 failure
fi

if [ "$OLDAF" != "" ]; then
printop "list table-of-contents of test archive with old afio"
if ! $OLDAF -tvzZ t2.afn >t2.afot 2>t2.afot2; then
 cat t2.afot2
 failure
fi
fi

printop "list table-of-contents of test archive with new afio"
if ! $NEWAF -tvzZ t2.afn >t2.afnt 2>t2.afnt2; then
 failure
fi

if [ "$OLDAF" != "" ]; then
printop "compare table-of-contents files generated by new and old afio"
if ! cmp t2.afot t2.afnt; then
 diff -U 0 t2.afot t2.afnt
 failure
fi
fi

printop "compare table-of-contents file made by new afio with archived toc"
#filter out date/time from tocs to account for timezone differences and
#changed time/date stamps on dirs and symlinks
 $AWK '{gsub("... .. ..:..:.. ....","DATE"); print;}' $TESTTOC >t2.x
 $AWK '{gsub("... .. ..:..:.. ....","DATE"); print;}' t2.afnt >t2.y
if [ "`whoami`" = root ]; then
#also, uid/gid to name mappings may also have changed, so filter out non-root files
 grep -v "^[dl]" $TESTTOC | grep "root *root" <t2.x >t2.xx
 grep -v "^[dl]" t2.afnt | grep "root *root" <t2.y >t2.yy
else
#filter out date/time from tocs to account for timezone differences and
#changed time/date stamps on dirs and symlinks
#also, archived toc uses user root, so blank out user and group fields.
 $AWK '{$3="x"; $4="x"; print; }' <t2.x >t2.xx
 $AWK '{$3="x"; $4="x"; print; }' <t2.y >t2.yy
fi
sort -t @ < t2.xx >t2.arch
sort -t @ < t2.yy >t2.new
if ! cmp t2.arch t2.new; then
 diff -U 0 t2.arch t2.new
 failure
fi

if [ "$OLDAF" != "" ]; then
printop "compare table-of-contents operation -z stderr generated by new and old afio"
$AWK '{gsub("[0-9]* second","XX second"); print}' <t2.afot2 >t2.afot2x
$AWK '{gsub("[0-9]* second","XX second"); print}' <t2.afnt2 >t2.afnt2x
if ! cmp t2.afot2x t2.afnt2x; then
 failure
 diff -U 0 t2.afot2x t2.afnt2x
fi
fi

printop "check if (the local version of) cpio can list the toc of an afio archive"
#gnu cpio needs -H odc, if we do not detect gnu cpio then try -c flag.
flags="-itv -c"
if cpio --version >t5.cv 2>/dev/null; then
 if grep GNU t5.cv >/dev/null; then
  flags="-tv -H odc"
 fi
fi
if [ "x$flags" != "x-tv -H odc" ]; then
 echo ..no GNU cpio found, trying the installed cpio with $flags flags.
fi
if ! cpio $flags <t2.afn >t2.afn.c1 2>t2.afn.c2; then
 cat t2.afn.c2
 failure
else
#gnu cpio does not seem to return error status on some errors, so
#check if stderr had anything...
if grep -v blocks t2.afn.c2 >/dev/null; then
 cat t2.afn.c2
 failure
fi
fi




if [ $failed = 1 ]; then
 echo " -------------- "
 echo THERE WERE REGRESSION TEST FAILURES
fi

