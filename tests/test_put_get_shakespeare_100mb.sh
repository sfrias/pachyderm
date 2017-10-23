#!/bin/bash

set -x

THIS_DIR="$(dirname $0)"

[[ -d ./shakespeare_test ]] && rm -r ./shakespeare_test
for r in gcs gsutil-stream cat-stream local-path; do
  pachctl delete-repo shakespeare-${r}
  pachctl create-repo shakespeare-${r}
  mkdir -p ./shakespeare_test/${r}/{output,comparison}
done

COMMIT=$(pachctl start-commit shakespeare-gcs master | tee /dev/stderr)
pachctl put-file shakespeare-gcs "${COMMIT}" / -r -f gs://shakespeare_plays
pachctl finish-commit shakespeare-gcs "${COMMIT}"

COMMIT=$(pachctl start-commit shakespeare-cat-stream master | tee /dev/stderr)
for f in 1mb 100mb; do
  cat "${THIS_DIR}/testdata/shakespeare_plays/shakespeare_plays_${f}.txt" | pv | pachctl put-file shakespeare-cat-stream ${COMMIT} /shakespeare_plays_${f}.txt -f -
done
pachctl finish-commit shakespeare-cat-stream "${COMMIT}"

COMMIT=$(pachctl start-commit shakespeare-gsutil-stream master | tee /dev/stderr)
for f in 1mb 100mb; do
  gsutil cp gs://shakespeare_plays/shakespeare_plays_${f}.txt - | pv | pachctl put-file shakespeare-gsutil-stream ${COMMIT} /shakespeare_plays_${f}.txt -f -
done
pachctl finish-commit shakespeare-gsutil-stream "${COMMIT}"

COMMIT=$(pachctl start-commit shakespeare-local-path master | tee /dev/stderr)
for f in 1mb 100mb; do
  pachctl put-file shakespeare-local-path ${COMMIT} /shakespeare_plays_${f}.txt -f "${THIS_DIR}/testdata/shakespeare_plays/shakespeare_plays_${f}.txt"
done
pachctl finish-commit shakespeare-local-path "${COMMIT}"

for r in gcs gsutil-stream cat-stream local-path; do
  for f in 1mb 100mb; do
    pachctl get-file shakespeare-${r} master /shakespeare_plays_${f}.txt -o shakespeare_test/${r}/output/shakespeare_plays_${f}.txt
  done
done

set +x

echo -e "\n############## original data ##############"
ls -l testdata/shakespeare_plays/
find testdata/shakespeare_plays/ -name *.txt | while read f; do md5sum $f; done

echo -e "\n############## experimental data ##############"
ls -lR shakespeare_test/*/output/
find shakespeare_test/*/output/ -name *.txt | while read f; do md5sum $f; done

