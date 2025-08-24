 
          #!/bin/bash
          set -e

          # specify the path to the single env-details file
          
          ENV_FILE_PATH="./${{ inputs.filepath }}"
          
          while read line; do
              CHART=$(echo $line | cut -d':' -f1)
              TAG=$(echo $line | cut -d'|' -f1 | cut -d':' -f2 | tr -d ' ')
              echo -e "\n==============Chart Details: $CHART:$TAG================"

              rm -rf charts/$CHART || true
              echo $S_PASS | helm registry login ghcr.io --username $S_USER --password-stdin
              helm pull oci://$S_REG/$CHART --version $TAG --untar -d ./charts || {
                echo "Chart Details: $CHART:$TAG not found. Skipping..."  >> $GITHUB_STEP_SUMMARY
                continue
              }
              ls -ltr
              cd ./charts/$CHART

              sed -i "s|$S_REG|$VS_REG|g" values.yaml

              echo -e "\n**** Repo name in $CHART values file"
              grep "repository: " values.yaml || true

              if [[ ! "$CHART" =~ ^(com-met|hello|metadata)$ ]]; then
                  IMAGE=$(helm template . | grep "image:" | awk '${print $2}' | tr -d "\"")
                  echo -e "**** Images associated with Chart:\n $IMAGE"
                  echo $VS_PASS | docker login ghcr.io -u $VS_USER --password-stdin

                  IMAGE_MISSING=false
                  for i in $IMAGE
                  do
                      if docker mainfest inspect "$i" > /dev/null 2>&1; then
                          echo -e "\n**** Image $i exists"
                      else
                          echo -e "Image $i does not exist, continue"  >> $GITHUB_STEP_SUMMARY
                          IMAGE_MISSING=true
                      fi
                  done

                  if [ "$IMAGE_MISSING" = true ]; then
                      echo "One or more images for $CHART:$TAG not found. Skipping chart packaging and pushing..." >> $GITHUB_STEP_SUMMARY
                      continue
                  fi
              else
                 echo "Skipping the Image validation $CHART chart"

              fi

              helm package . 
              mv $CHART-$TAG.tgz ../../

              cd ../../

              echo $VS_PASS | docker login ghcr.io -u $VS_USER --password-stdin
              helm push $CHART-$TAG.tgz  oci://$VS_REG

              echo "**** Pushed $CHART-$TAG to $VS_REG"
              echo "**** Pushed $CHART-$TAG to $VS_REG" >> $GITHUB_STEP_SUMMARY

              rm -rf ./charts/$CHART || true
              rm $CHART-$TAG.tgz

          done < "$ENV_FILE_PATH"