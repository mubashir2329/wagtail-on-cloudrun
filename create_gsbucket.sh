# creating gs bucket
GS_BUCKET_NAME=${PROJECT_ID}-media
gsutil mb -l ${REGION} gs://${GS_BUCKET_NAME}


# allow cross origin resource sharing(Cors) for our bucket 
gsutil cors set cors.json gs://$GS_BUCKET_NAME