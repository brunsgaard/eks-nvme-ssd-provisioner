FROM alpine:3.12

RUN apk add --update-cache mdadm nvme-cli bash e2fsprogs
COPY eks-nvme-ssd-provisioner.sh /usr/local/bin/

ENTRYPOINT ["eks-nvme-ssd-provisioner.sh"]
