[webservers]
${ssh_host} ansible_host=${server_ip}

[webservers:vars]
ansible_port=${ssh_port}
ansible_user=${ansible_user}
ansible_ssh_private_key_file=${ssh_private_key_file}
public_domain=${public_domain}
public_www_domain=${public_www_domain}
certbot_email=${certbot_email}
certbot_staging=${certbot_staging}
