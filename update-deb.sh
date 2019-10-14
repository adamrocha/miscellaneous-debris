#!/usr/bin/env bash

apt update
apt dist-upgrade -y
apt autoremove -y
apt autoclean
