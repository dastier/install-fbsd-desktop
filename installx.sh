#!/bin/sh
# Nick Bernstein https://github.com/nicholasbernstein/install-fbsd-desktop
# most of this comes from the freebsd handbook 5.4.1. Quick Start x-config
date > installx.log

echo "kern.vty=vt" >> /boot/loader.conf
# this is mainly just to make sure pkg has been bootstrapped
export ASSUME_ALWAYS_YES=yes
pkg update | tee -a installx.log

# Your user needs to be in the video group to use video acceleration
default_user=`grep 1001 /etc/passwd | awk -F: '{ print $1 }'`
VUSER=`dialog --title "Video User" --clear \
        --inputbox "What user should be added to the video group?" 0 0  $default_user --stdout`

pw groupmod video -m $VUSER 

# probably not necessary, logging into an x session as root isn't recommended.
pw groupmod video -m root

# the following creates a .xinitrc file in the user's home directory that will launch
# the installed windowmanager as well as allow the slim display manager to pass it as
# an argument. 
gen_xinit() {
	if [ ! $1 ] ; then 
		echo "argument needed by gen_xinit" 
		return 0 
	else
		xinittxt="#!/bin/sh\n mywm="$1"\n if [ \$1 ] ; then\n \tcase \$1 in \n \t\tdefault) exec \$mywm ;;\n \t\t*) exec \$1 ;;\n \tesac\n else\n \texec $mywm\n fi"
		echo -e $xinittxt > /home/$VUSER/.xinitrc && chown $VUSER:$VUSER /home/$VUSER/.xinitrc
		echo -e $xinittxt > /etc/skel/.xinitrc
	fi
}


# lets pick our desktop environment. SDDM is going to be used as the login 
# manager instead of slim since it "works out of the box" w/o .xinitrc stuff

set_login_mgr() { 
	if (uname -r | grep "11" >/dev/null) ; then
		mywm="slim"
		slim_extra_pkgs="slim-freebsd-dark-theme"
		pwd_mkdb -p /etc/master.passwd
	else 
		mywm="sddm"
	fi
}

set_login_mgr

desktop=$(dialog --clear --title "Select Desktop" \
        --menu "Select desktop environment to be installed" 0 0 0 \
        "KDE"  "KDE (FBSD 12+ only)" \
        "lxde"  "The lightweight X Desktop ENvironment" \
	"LXQT" "Lightweight QT Desktop (FBSD 12+ only)" \
        "Gnome3" "The modern Gnome Desktop" \
        "xfce4" "Lightweight XFCE desktop" \
        "windowmaker" "bringing neXt back" \
        "awesome" " a tiling window manager" \
        "mate"  "Mate dekstop based on gtk" --stdout)

# for any additional entries, please add a case statement below

case $desktop in
  KDE)
      gen_xinit "startkde"
      DESKTOP_PGKS="kde5 ${mywm}" 
      sysrc ${mywm}_enable="YES"
      ;;
  windowmaker)
      gen_xinit "/usr/local/bin/wmaker"
      DESKTOP_PGKS="kde5 ${mywm}" 
      DESKTOP_PGKS="windowmaker wmakerconf ${mywm}" 
      sysrc ${mywm}_enable="YES"
cat <<EOT>/usr/local/share/xsessions/wmaker.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Windowmaker
Comment=Windowmaker Desktop Environment
Exec=/usr/local/bin/wmaker
Icon=
Type=Application
EOT
      ;;
  LXQT)
      gen_xinit "startlxqt"
      DESKTOP_PGKS="lxqt ${mywm}" 
      sysrc ${mywm}_enable="YES"
      ;;
  lxde)
      gen_xinit "startlxde"
      DESKTOP_PGKS="lxde-meta lxde-common ${mywm}" 
      sysrc ${mywm}_enable="YES"
      ;;
  Gnome3)
      gen_xinit "gnome-session"
      DESKTOP_PGKS="gnome3" 
      sysrc gnome_enable="YES"
      sysrc gdm_enable="YES"
      sysrc ${mywm}_enable="NO"
      ;;
  xfce4)
      gen_xinit "startxfce4"
      DESKTOP_PGKS="xfce ${mywm}" 
      sysrc ${mywm}_enable="YES"
      ;;
  mate)
      gen_xinit "mate-session"
      echo $desktop
      DESKTOP_PGKS="mate ${mywm}" 
      sysrc ${mywm}_enable="YES"
      ;;
  awesome)
      gen_xinit "awesome"
      DESKTOP_PGKS="awesome ${mywm}" 
      sysrc ${mywm}_enable="YES"
      ;;
  *)
     echo "$desktop isn't a valid option."
     ;;
esac

# The following are generally needed by most modern desktops

sysrc dbus_enable="YES"
sysrc hald_enable="YES"

grep "proc /proc procfs" /etc/fstab || echo "proc /proc procfs rw 0 0" >> /etc/fstab
#!/bin/sh

# A number of the more lightweight desktops don't include everything you need
# and anyone coming from linux probably wants bash, sudo & vim. Let's make
# the transition easy for them

extra_pkgs=$(dialog --checklist "Select additional packages to install" 0 0 0 \
firefox "Firefox Web browser" on \
bash "GNU Bourne-Again SHell" on \
vim-console "VI Improved" on \
git-lite "lightweight git client" on \
sudo "superuser do" on \
thunderbird "Thunderbird Email Client" off \
obs-studio "OBS-Studio recording/casting" off \
audacity "Audacity music editor" off \
simplescreenrecorder "Does it need a description?" off \
libreoffice "open source & nice suite" off \
vlc "Video Player" off \
doas "simpler alternative to sudo" off \
linux_base-c7 "centos v7 linux binary compatiblity layer" off \
virtualbox-ose-additions "virtualbox guest additions" off \
--stdout)

# This is a little ugly, but we need to set some sysrc settings
# and dialog is nice to look at, but is kinda clunky

if ( echo $extra_pkgs | grep "linux_base-c7" >/dev/null )    ; 
	then 
		sysrc kld_list+="linux"
		sysrc kld_list+="linux64"
		sysrc linux_enable="YES"

		mkdir -p /compat/linux/proc /compat/linux/dev/shm /compat/linux/sys
		grep "/compat/linux/proc" /etc/fstab 2>/dev/null || \
			echo "linprocfs   /compat/linux/proc  linprocfs rw 0 0" >> /etc/fstab
		grep "/compat/linux/sys" /etc/fstab 2>/dev/null || \
			echo "linsysfs    /compat/linux/sys   linsysfs  rw 0 0" >> /etc/fstab
		grep "/compat/linux/dev" /etc/fstab 2>/dev/null || \
			echo "tmpfs    /compat/linux/dev/shm  tmpfs rw,mode=1777 0 0" >> /etc/fstab
fi

if ( echo $extra_pkgs | grep "virtualbox-ose-additions" >/dev/null )    ; 
	then 
		sysrc vboxguest_enable="YES"
		sysrc vboxservice_enable="YES"
fi

# Honestly, shouldn't graphic card configuration be done in the base installer? 
# Even if X isn't enabled, the right drivers should be selected and installed.
# Lets handle the 4 major cases, and hope for the best

dialog --title "Graphics Drivers" --yesno "Would you like to try to install the drivers for your video card?\n\nPlease refer to freebsd handbook for more details:\nhttps://www.freebsd.org/doc/handbook/x-config.html" 0 0

install_dv_drivers=$?
if [ $install_dv_drivers -eq 0  ] ; then 

	card=$(dialog --checklist "Select additional packages to install" 0 0 0 \
	i915kms "most Intel graphics cards" off \
	radeonkms "most OLDER Radeon graphics cards" off \
	amdgpu "most NEWER AMD graphics cards" off \
	nvidia "NVidia Graphics Cards" off \
	other "Anything but the above" off \
	--stdout)

	case $card in
		i915kms) 
			vc_pkgs="drm-kmod"
			sysrc kld_list+="/boot/modules/i915kms.ko"
			;;
		radeonkms) 
			vc_pkgs="drm-kmod"
			sysrc kld_list+="/boot/modules/radeonkms.ko"
			;;
		amdgpu) 
			vc_pkgs="drm-kmod"
			sysrc kld_list+="amdgpu"
			;;
		nvidia) 
			vc_pkgs="nvidia-driver nvidia-xconfig nvidia-settings"
			nvidia-xconfig
			sysrc kld_list+="nvidia-modeset nvidia"
			;;
		*)
			dialog --msgbox "You'll need to check the freebsd handbook or forums" 0 0
			;;
	esac

fi 

#
# this comment is just to draw attention to
# the fact that this line is doing the package installs
# and making it easy to find by having a big comment block
# above it
#
base_pkgs="xorg hal dbus"
all_pkgs="$base_pkgs $DESKTOP_PGKS $extra_pkgs $vc_pkgs $slim_extra_pkgs"
echo "pkg install -y $all_pkgs" | tee -a installx.log
pkg install -y $all_pkgs | tee -a installx.log

# post install stuff
if [ "slim" = $mywm ] ; then
	sed -i '' -E 's/^current_theme.+$/current_theme		slim-freebsd-dark-theme/' /usr/local/etc/slim.conf
fi

# make sudo behave like default linux setup
if ( echo $all_pkgs | grep "sudo" > /dev/null ) ; then
	echo "%wheel ALL=(ALL) ALL" >> /usr/local/etc/sudoers
fi

# on 11.x w/ mate re-installing fixed a core-dump
if [ $desktop = "mate" ] ; then 
	if ( echo $(uname -r) | grep "11" > /dev/null ) ; then 
		pkg install -f gsettings-desktop-schemas
	fi
fi

dialog --msgbox "Hopefully that worked. You'll probably want to reboot at this point" 0 0

