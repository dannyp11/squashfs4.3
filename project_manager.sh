#!/bin/bash
# Warning: this script only works and tested on Linux system, especially Ubuntu 14 and Fedora 22
# 
# Extra project maintaining script for easier testing & maintaining

# global vars
SCRIPT_NAME="$0"
SRC_DIR="squashfs-tools"
RETVAL=0

# print colored title
print_title()
{
	local RED='\033[0;31m'
	local GREEN='\033[0;32m'
	local NC='\033[0m' # No Color

	local txt=$@
	echo -e "\n${GREEN}|=============================================="
	echo "| $txt"
	echo -e "|==============================================${NC}"
}

# print colored warning
print_warning()
{
	local RED='\033[0;31m'
	local GREEN='\033[0;32m'
	local NC='\033[0m' # No Color

	local txt=$@
	echo -e "\n${RED}|=============================================="
	echo "| $txt"
	echo -e "|==============================================${NC}"
}

function usage()
{
cat <<EOF
 Usage: $SCRIPT_NAME OPTION
 Extra project maintaining script for easier testing & maintaining
    
    OPTION
    -b      build the project
    -t      test the project and report
    -c      maintainer clean, cleaner than make clean
    -p      create patch from this project to original 4.3 version
    -h      this message
EOF
    
    exit -1
}

function runClean()
{
    pushd $SRC_DIR
        make clean
        rm -f *.o     
    popd
}

function runBuild()
{
    print_title "Building $SRC_DIR"
    pushd $SRC_DIR
        make -j4
        local retMake=$?
        ((RETVAL = RETVAL + retMake))
    popd
    
    if [ $RETVAL != 0 ]; then
        print_warning "Error code $RETVAL building project"
        exit $RETVAL
    fi
}

function runTest()
{    
    # build the project
    runBuild
    
    # create random large files
    print_title "Creating random files"
    local file1=file1.file
    local file2=file2.file
    
    head -c 50000 </dev/urandom >$file1
    head -c 100000 </dev/urandom >$file2
    
    # make 2 squash files
    local mksquash=$SRC_DIR/mksquashfs
    local squash1=$file1.squash
    local squash2=$file2.squash
    
    $mksquash $file1 $file2 $file1.squash -no-date
    local cksum1=$(echo $(cksum $squash1) | head -n1 | cut -d " " -f1)

    # wait a while then create other squash
    sleep 5    
    $mksquash $file1 $file2 $file2.squash -no-date
    local cksum2=$(echo $(cksum $squash2) | head -n1 | cut -d " " -f1)
    
    # compare 2 cksums
    if [ $cksum1 == $cksum2 ]; then
        print_title "Test ran successfully"
    else
        print_warning "Error: cksum mismatch"
        ((RETVAL = RETVAL + 1))
    fi
    
    # cleanup test
    rm -f $file1 $file2 $squash1 $squash2
    runClean    
}

function createPatch()
{
    print_title "Creating patch..."

    local oldProjDir=squashfs4.3
    local newProjDir=$oldProjDir-new
    local patchName=$oldProjDir-nodate.patch    
    rm -f $patchName
    
    # First test to make sure we have a working version
    runTest
    
    if [ $RETVAL != 0 ]; then
        print_warning "Can't create patch because the test fails"
        exit $RETVAL
    fi
      
    # Create dir for the new project
    local tarFile=squashfs4.3.tar.gz
    rm -rf $oldProjDir $newProjDir
    mkdir $newProjDir
    
    # download old version
    wget 'https://cytranet.dl.sourceforge.net/project/squashfs/squashfs/squashfs4.3/squashfs4.3.tar.gz' -O $tarFile
    if [ $? != 0 ]; then
        print_warning "Error downloading $tarFile"
        exit 1
    fi
    
    # untar old version
    tar xzf $tarFile
    rm $tarFile
    if [ ! -d $oldProjDir ]; then
        print_warning "Can't find extracted files"
        exit 2
    fi    
    
    # cp new files to new version
    rsync -av --exclude='*.yml' --exclude='.git' --exclude='project_manager.sh' \
              --exclude=$newProjDir --exclude=$oldProjDir \
              --exclude='*.patch' \
            . $newProjDir
    
    # finally, create patch
    diff -ruNa $oldProjDir $newProjDir > $patchName
    
    # cleanup everything
    rm -rf $oldProjDir $newProjDir
    
    print_title "Successfully created $patchName"
    
    exit $RETVAL
}

# main ##############################################################
# getopt
while getopts "tcbph" o; do
    case "${o}" in
        c)            
            runClean
            exit $RETVAL       
            ;;
        t)
            runTest
            exit $RETVAL
            ;;
        b)
            runBuild
            exit $RETVAL
            ;;
        p)
            createPatch
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# if no option is chosen, print help menu
usage
