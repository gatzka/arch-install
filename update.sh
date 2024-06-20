#!/bin/bash
fwupdmgr refresh --force && fwupdmgr get-updates && fwupdmgr update
yay -Syu && yay -Qtdq | yay -Rns -

