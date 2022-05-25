FROM gcr.io/k8s-staging-boskos/janitor
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get --allow-releaseinfo-change update -y
RUN apt-get install libvirt-clients libvirt-dev  -y --fix-missing
