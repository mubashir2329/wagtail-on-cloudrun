# create confirguration in .env file
echo DATABASE_URL=\"postgres://djuser:${PASSWORD}@//cloudsql/${PROJECT_ID}:${REGION}:${SQL_INSTANCE_ID}/mydatabase\" > .env
echo GS_BUCKET_NAME=\"${GS_BUCKET_NAME}\" >> .env
echo SECRET_KEY=\"$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)\" >> .env
echo DEBUG=\"True\" >> .env

# create application_settings secret
gcloud secrets create application_settings --data-file .env
gcloud secrets versions list application_settings

# create admin_password secret for django super user 
gcloud secrets create admin_password --replication-policy automatic
USER_PASSWORD=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)
echo -n $USER_PASSWORD | gcloud secrets versions add admin_password --data-file=-


rm .env 