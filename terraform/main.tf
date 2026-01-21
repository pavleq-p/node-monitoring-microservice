# настройка самого терраформ
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}
# настройка провайдера 
provider "yandex" {
  service_account_key_file = "./key.json"
  folder_id = "b1gqov5nc2otnogjsai2" 
  zone = "ru-central1-a"
}

# описание ресурсов
# 1.описание диска
resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "30"
  image_id = "fd80bm3tac4pvt8dntvf" # AlmaLinux 9
}

# 2.описание виртуальной машины
resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "almalinux:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# 3.описание сети и подсети
data "yandex_vpc_network" "default" {
  name = "default"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name       = "subnet1"
  zone       = "ru-central1-a"
  network_id = data.yandex_vpc_network.default.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}
# вывод информации (внутренний и внешний IP ВМ)
output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

# 4.ЗАПУСК ANSIBLE ПОСЛЕ СОЗДАНИЯ ВМ 
resource "null_resource" "run_ansible" {
  depends_on = [yandex_compute_instance.vm-1]
  
  triggers = {
    vm_ip = yandex_compute_instance.vm-1.network_interface[0].nat_ip_address
    playbook_hash = filebase64sha256("../ansible/playbook.yml")
  }

  # для проверки, что ВМ готова
  connection {
    type        = "ssh"
    user        = "almalinux"
    private_key = file("~/.ssh/id_ed25519")
    host        = yandex_compute_instance.vm-1.network_interface[0].nat_ip_address
    timeout     = "5m"
  }

  # Запуск Ansible 
  provisioner "local-exec" {
    working_dir = "../ansible"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u almalinux --private-key ~/.ssh/id_ed25519 -i '${yandex_compute_instance.vm-1.network_interface[0].nat_ip_address},' playbook.yml -kK -vv"
  }
}