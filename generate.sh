#!/bin/bash
endTime=3
#git clone https://github.com/modelica-tools/FMUComplianceChecker.git fmu-cc

cd fmu-cc
git checkout 2.0.3b3
mkdir -p build
cd build
cmake ../ &> /dev/null
make -j6 &>/dev/null
cd ../..

check=fmu-cc/build/fmuCheck.darwin64

#wget -v http://overture.au.dk/into-cps/vdm-tool-wrapper/development/latest/fmu-import-export.jar -O overture-fmu-export.jar

fx=overture-fmu-export.jar

if [ -f "$fx" ]
then
		echo "$fx is already downloaded."
else
		wget -v http://overture.au.dk/into-cps/vdm-tool-wrapper/master/latest/fmu-import-export.jar -O $fx
fi

#wget -v http://overture.au.dk/into-cps/vdm-tool-wrapper/master/latest/fmu-import-export.jar -O overture-fmu-export.jar

version=`java -jar $fx -V | tail -n 1`
echo $version
for word in $version
do
    version=$word
done

echo $version


for D in `find Models -type d -maxdepth 1 -mindepth 1`
do
		echo processing $D
		p=`readlink -f $D`
		name=`basename $D`
		echo $name
		java -jar overture-fmu-export.jar -export tool -name $name -output FMUs -root $p
done


outRoot=CrossCheck/Overture/$version

for fmu in `find FMUs -type f -name "*.fmu"`
do
		filename="${fmu##*/}"
		filename="${filename%.*}"

		ccFmuRoot=$outRoot/$filename

		mkdir -p $ccFmuRoot

		#copy fmu
		cp $fmu $ccFmuRoot

 ccCmdArgs=" -h 0.001 -l 3 -s $endTime -o "${ccFmuRoot}/${filename}_cc.csv" "${fmu}""

		ccCmd="$check $ccCmdArgs"

		$ccCmd &> "${ccFmuRoot}/${filename}_cc.log"
#		echo `basename $check` $ccCmdArgs > "${ccFmuRoot}/${filename}_cc.sh"

shortFmu=`basename $fmu`
ccCmdArgs=" -h 0.001 -l 3 -s $endTime -o "${filename}_cc.csv" "${shortFmu}""

cat << EOT > "${ccFmuRoot}/${filename}_cc.sh"
#!/bin/bash

cc=./fmuCheck.darwin64
unamestr=\`uname\`
if [[ "\$unamestr" == 'Linux' ]]; then

if \$(uname -m | grep '64'); then
  cc=./fmuCheck.linux64
else
  cc=./fmuCheck.linux32
fi

else
   cc=./fmuCheck.darwin64
fi

\$cc $ccCmdArgs

EOT


echo fmuCheck.win* $ccCmdArgs > "${ccFmuRoot}/${filename}_cc.bat"
		cat "${ccFmuRoot}/${filename}_cc.log"

		#the cross checker is adding two headers so get rid of the first
		#echo `tail -n +2 "${filename}_cc.csv"` > "${filename}_cc.csv"
		sed -i.bak '1d' "${ccFmuRoot}/${filename}_cc.csv"
		rm ${ccFmuRoot}/*.bak

		cp "${ccFmuRoot}/${filename}_cc.csv" "${ccFmuRoot}/${filename}_ref.csv"

		cat  << EOT > "${ccFmuRoot}/ReadMe.txt"
This model is a VDM-RT model exported by Overture FMU Exporter:

$version

To use the FMU Java 1.8 or later is required.

EOT

		cat << EOT > "${ccFmuRoot}/${filename}_ref.opt"
StepSize,0
StartTime,0
StopTime,$endTime
RelTol,1e-4
EOT
done
