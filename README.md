# ansible-vm
Ansible playbook for setting greenfield VM deployment

## TODO
- [ ] Setup initial play
- [x] Install packages
- [x] Install Docker
- [x] Install Portainer
- [x] Install Node Exporter

## Requirements (Ansible Collections)
- docker - https://galaxy.ansible.com/community/docker

Run the requirements install
```
ansible-galaxy collection install -r requirements.yaml
```

## Installation
```
ansible-playbook -i hosts.yaml all.yaml
```

You can use tags to only run some of the roles.
```
ansible-playbook -i hosts.yaml all.yaml --tags=portainer
```

## Accessing Prometheus Metrics
With Node Exporter configured, metrics are accessible at `http://<vm-hostname>:9100/metrics`