#!/bin/bash -l

echo "sourcepath: $1"
echo "environment-variables: $2"

rustup toolchain list
rustup target list | grep \(installed\)
rustup component list | grep \(installed\)

sourcePath=system/hamr/microkit
if [[ -n $1 ]]; then
	sourcePath=$1
fi

if [[ -n $2 ]]; then
	for kv in $(echo $2 | jq -r 'to_entries | .[] | .key + "=" + (.value | @sh)'); do
		echo "setting ${kv}"
		export $kv;
	done
fi

runCommand=(make -C $GITHUB_WORKSPACE/${sourcePath} test)

reportFile='codetest-report.json'
if [[ -n $3 ]]; then
	reportFile=$3
fi

echo "run command: ${runCommand[@]}" 

outputFile=$(mktemp)
"${runCommand[@]}" >> "$outputFile" 2>&1
EXIT_CODE=$?
cat $outputFile

chmod -R +r $sourcePath

echo "timestamp=$(date)" >> $GITHUB_OUTPUT
echo "status=${EXIT_CODE}" >> $GITHUB_OUTPUT

# Collect codetest report
codetestMessages=$(mktemp)
cat ${outputFile} | jq --raw-input . | jq --slurp '{"messages" : .}' > "${codetestMessages}"
cat ${codetestMessages} \
    | jq --arg timestamp "$(date)" --arg exitcode ${{ steps.codetest.outputs.status }} '. += $ARGS.named' \
    > ${reportFile}
rm ${outputFile} ${codetestMessages}

echo "exit code: $EXIT_CODE"
if [ "XX $EXIT_CODE" = "XX 0" ]; then
	exit 0
else
	exit 1
fi
