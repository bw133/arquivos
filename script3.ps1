
# Verifica se o OpenSSH Server está instalado
$sshServerInstalled = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

if ($sshServerInstalled.State -ne 'Installed') {
    Write-Host "OpenSSH Server não está instalado. Instalando agora..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Write-Host "OpenSSH Server instalado com sucesso."
} else {
    Write-Host "OpenSSH Server já está instalado."
}

# Definições do usuário e diretórios
$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[1]
$UserProfile = "C:\Users\$UserName"
$SshDir = "$UserProfile\.ssh"
$AuthorizedKeysFile = "$SshDir\authorized_keys"
$SshConfigFile = "C:\ProgramData\ssh\sshd_config"

# Verifica se o usuário faz parte do grupo de administradores
if (-Not (Get-LocalGroupMember -Group "Administradores" -Member $UserName -ErrorAction SilentlyContinue)) {
    Add-LocalGroupMember -Group "Administradores" -Member $UserName
    Write-Host "Usuário '$UserName' adicionado ao grupo Administradores."
} else {
    Write-Host "Usuário '$UserName' já é membro do grupo Administradores."
}

# Cria o diretório .ssh se não existir
if (-Not (Test-Path -Path $SshDir)) {
    New-Item -ItemType Directory -Path $SshDir -Force
}

# Chave pública fornecida para adicionar ao authorized_keys
$ProvidedPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNv7QNtNCpXXTarXx1+7q/9Lip69Tnhie0rlXi0KDKFjJuFwmRGfZgqc6PBOe4sRzBX1ABA3iinyOhs2vt0n+7kAAB+VRlcoaRDRqQXva38mmMIKuALk4JG3OMDIrGnZF+ddgepVoJfg5yCUhW62QoV8eG/0W5wmiGg/IQ+2z4IpRl5aXbCNKtxKnUi4ZXgwBN3sGQl0Gx8HLUjFo7nsw8XbyoPHo1sB7casMpD5JoYV1RLRimMAJtlRi6KfQa0GVDu53rvYO43GLGLHrFHFrIy0HMP4T1vmKpes0Q34nbhPSlnjAjAv8gUF/XuVJH+IT0XxAl5ttaya2mxhmsR3H7P7a0qY/sbohxJhRuLGdHsQpsoseRlvvAp3pRgLkKU4ZWLNVkoosjsXLvRfzzIweI6D3s3mVGO0wLAgTl0MxK3eOqKyneFD8S56ZY4fGaQCYwFMJeVtzkV/N4h5eIEZLauhJ3seaT0ME6CXTE4ZJJV7P58w7V9XpsQc0ebtfvWidUWKugKJfcJkw+GYnRWPB4PILpggiognksRdaVQi3MR5Uxlrggb11NC9tJ0SdZKybYa+oB49nceaykBA035NNn3QsTM+vdlzURKFJWv2OKicVwy8eZ3ZLu6UXxqBSqBGzsDdZk6dtF2oxp1m9mYZOYgErJp5Wx4H072/xXwqw8Ww== "

# Verifica se o arquivo authorized_keys existe, se não, cria-o
if (-Not (Test-Path -Path $AuthorizedKeysFile)) {
    New-Item -ItemType File -Path $AuthorizedKeysFile -Force
}

# Adiciona a chave pública fornecida ao arquivo authorized_keys
Add-Content -Path $AuthorizedKeysFile -Value $ProvidedPublicKey

# Conceder ao usuário atual permissões totais no arquivo authorized_keys
icacls $AuthorizedKeysFile /grant:r "${UserName}:(F)" /T /C
icacls $AuthorizedKeysFile /inheritance:r /T /C

Write-Host "Chave SSH fornecida adicionada ao arquivo authorized_keys para o usuário $UserName."

# Verifica se o arquivo sshd_config existe, se não, cria e adiciona as configurações mínimas
if (-Not (Test-Path -Path $SshConfigFile)) {
    Write-Host "Arquivo de configuração do SSH Server não encontrado. Criando arquivo sshd_config..."
    New-Item -Path $SshConfigFile -ItemType "File" -Force

    # Adiciona as configurações mínimas ao sshd_config
    $configContent = @"
# Configurações mínimas do SSH Server
Port 22
ListenAddress 0.0.0.0
ListenAddress ::

# Outras configurações comuns
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
"@
    Set-Content -Path $SshConfigFile -Value $configContent
    Write-Host "Arquivo sshd_config criado e configurado com sucesso."
} else {
    Write-Host "Arquivo de configuração do SSH Server encontrado."
}

# Tenta reiniciar o serviço SSH
Stop-Service sshd -Force -ErrorAction SilentlyContinue
Start-Service sshd -ErrorAction SilentlyContinue

if ((Get-Service sshd).Status -eq "Running") {
    Write-Host "Serviço SSH reiniciado com sucesso."
} else {
    Write-Host "Falha ao reiniciar o serviço SSH. Verifique o log do sistema para mais detalhes."
}
