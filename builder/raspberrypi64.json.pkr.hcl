packer {
  required_plugins {
    arm-image = {
      source  = "github.com/solo-io/arm-image"
      version = ">= 0.0.1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
  }
}

variable "pwn_hostname" {
  type = string
}

variable "pwn_version" {
  type = string
}

source "arm-image" "rpi64-pwnagotchi" {
  image_type      = "raspberrypi"
  iso_url         = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz"
  iso_checksum    = "sha256:43d150e7901583919e4eb1f0fa83fe0363af2d1e9777a5bb707d696d535e2599"
  output_filename = "../../../pwnagotchi-64bit.img"
  qemu_binary     = "qemu-aarch64-static"
  target_image_size = 19969908736
  image_mounts    = ["/boot/firmware","/"]
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/from-1.5/blocks/build
build {
  name = "Raspberry Pi 64 Pwnagotchi"
  sources = ["source.arm-image.rpi64-pwnagotchi"]

  provisioner "file" {
    destination = "/usr/bin/"
    sources     = [
      "data/64bit/usr/bin/bettercap-launcher",
      "data/64bit/usr/bin/hdmioff",
      "data/64bit/usr/bin/hdmion",
      "data/64bit/usr/bin/monstart",
      "data/64bit/usr/bin/monstop",
      "data/64bit/usr/bin/pwnagotchi-launcher",
      "data/64bit/usr/bin/pwnlib",
    ]
  }
  provisioner "shell" {
    inline = ["chmod +x /usr/bin/*"]
  }
  provisioner "shell" {
    inline = ["mkdir -p /usr/local/src/pwnagotchi"]
  }
  provisioner "file" {
    destination = "/usr/local/src/pwnagotchi/"
    source = "../"
  }
  provisioner "file" {
    destination = "/etc/systemd/system/"
    sources     = [
      "data/64bit/etc/systemd/system/bettercap.service",
      "data/64bit/etc/systemd/system/pwnagotchi.service",
      "data/64bit/etc/systemd/system/pwngrid-peer.service",
    ]
  }
  provisioner "file" {
    destination = "/etc/update-motd.d/01-motd"
    source      = "data/64bit/etc/update-motd.d/01-motd"
  }
  provisioner "shell" {
    inline = ["chmod +x /etc/update-motd.d/*"]
  }
  provisioner "shell" {
    inline = ["apt-get -y --allow-releaseinfo-change update", "apt-get -y dist-upgrade", "apt-get install -y --no-install-recommends ansible"]
  }
  provisioner "ansible-local" {
    command         = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 PWN_VERSION=${var.pwn_version} PWN_HOSTNAME=${var.pwn_hostname} ansible-playbook"
    extra_arguments = ["--extra-vars \"ansible_python_interpreter=/usr/bin/python3\""]
    playbook_file   = "raspberrypi64.yml"
  }
}