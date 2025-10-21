#!/bin/python3.9

import json
import subprocess
import logging
import os
import smtplib
from email.message import EmailMessage
from datetime import datetime

config_file = '/work/host-directory.json'
log_dir = '/var/log/backup-data'
backup_base = '/backup-folder/backup-test'
ssh_key = '/home/i/.ssh/id_rsa-2048'
email = 'zarko@not-such-domain.ca'
header = (
    "\n"
    "----------------------------------------\n"
    f"  Backup Run: {datetime.now():%Y-%m-%d %H:%M:%S}\n"
    "----------------------------------------\n"
)

def send_email(subject, body):
    """
    Sends an email using a local SMTP server.
    Args:
        subject (str): The subject of the email.
        body (str): The body content of the email.
    Notes:
        The sender's email address is hardcoded as 'zarko@not-such-domain.ca'.
        The email sending process is not blocking; if an exception occurs,
        it is logged, and the function continues execution.
    """
    msg = EmailMessage()
    msg.set_content(body)
    msg['Subject'] = subject
    msg['From'] = 'zarko@not-such-domain.ca'
    msg['To'] = email
    try:
        with smtplib.SMTP('localhost') as s:
            s.send_message(msg)
    except Exception as e:
        logging.error(f"Failed to send email: {e}")

def main():
    # Read json config
    with open(config_file) as f:
        config = json.load(f)

    # Check if backup_source section exists in config
    if 'backup_source' not in config:
        logging.error('No [backup_source] section found in config.')
        return

    # Iterate over hosts and remote directories to backup
    for host, remote_dir_s in config['backup_source'].items():
        for remote_dir in remote_dir_s:
            # Set log file and local backup directory
            log_file = f"{log_dir}/{host}.log"
            remote_dir = remote_dir.rstrip('/')
            local_dir = os.path.join(backup_base, host, remote_dir.lstrip('/'))
            os.makedirs(local_dir, exist_ok=True)
            # Log backup start and execute rsync
            with open(log_file, 'a') as logf:
                logf.write(header)
                logf.write(f"Starting rsync: {host}:{remote_dir} -> {local_dir}\n")
                rsync_cmd = [
                    'rsync', '-e', f'ssh -i {ssh_key}', '-avz', '--delete',
                    f'{host}:{remote_dir}/', f'{local_dir}/'
                ]
                try:
                    # Run rsync command and log output
                    result = subprocess.run(
                        rsync_cmd, check=True, capture_output=True, text=True
                        )
                    logf.write(result.stdout)
                except subprocess.CalledProcessError as e:
                    # Log rsync failure and send error email
                    error_msg = f'Rsync failed for {host}:{remote_dir} to {local_dir}\n{e.stderr}\n'
                    logf.write(error_msg)
                    send_email(f'From Host, Rsync Failed: {host}:{remote_dir}', error_msg)

if __name__ == '__main__':
    main()

