#!/bin/bash

# Settings
HOSTNAME="${1:-riasc-agent}"
TOKEN="${2:-XXXXX}"

IMAGE_FILE="2021-05-07-raspios-buster-armhf-lite"
IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-05-28/${IMAGE_FILE}.zip"

RIASC_IMAGE_FILE=${IMAGE_FILE/raspios/riasc-raspios}

function check_command() {
	if ! command -v $1 &> /dev/null; then
		echo "$1 could not be found"
		exit
	fi
}

# Check that required commands exist
echo "Check if required commands are installed..."
check_command guestfish
check_command wget
check_command unzip
check_command zip

# Download image
if [ ! -f ${IMAGE_FILE}.zip ]; then
	echo "Downloading image.."
	wget ${IMAGE_URL}
fi

# Unzip image
if [ ! -f ${IMAGE_FILE}.img ]; then
	echo "Unzipping image..."
	unzip ${IMAGE_FILE}.zip
fi

# Prepare config
cp ../common/riasc.yaml riasc.yaml
sed -i \
	-e "s/XXXXX/${TOKEN}/g" \
	-e "s/riasc-agent/${HOSTNAME}/g" \
	riasc.yaml

# Patching image
echo "Patching image with guestfish..."
guestfish <<EOF
echo "Loading image..."
add ${IMAGE_FILE}.img

echo "Start virtual environment..."
run

echo "Available filesystems:"
list-filesystems

echo "Mounting filesystems..."
mount /dev/sda2 /
mount /dev/sda1 /boot

echo "Available space:"
df-h

echo "Copy files into image..."
copy-in rootfs/etc/ rootfs/usr/ /
copy-in riasc.yaml /boot

echo "Enable SSH on boot..."
touch /boot/ssh

echo "Setting hostname..."
write /etc/hostname "${HOSTNAME}"

echo "Enable systemd risac-update service..."
ln-sf /etc/systemd/system/risac-update.service /etc/systemd/system/multi-user.target.wants/risac-update.service
EOF

# Zip image
echo "Zipping image..."
zip ${RIASC_IMAGE_FILE}.zip ${IMAGE_FILE}.img
