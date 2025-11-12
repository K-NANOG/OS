# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{

  services.n8n.enable = true;
  services.n8n.openFirewall = true;       # Optional: opens firewall port for n8n
  
  
  ########################
  ## Unfree
  ########################
  nixpkgs.config.allowUnfree = true;

  #####################################
  ## Virtualisation (Docker)
  #####################################
  virtualisation = {
    docker = {
      enable = true;
      # rootless.enable = true;    # uncomment if you prefer rootless
    };
  };


  ############################################################
  ## Base: hardware + boot
  ############################################################
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ############################################################
  ## Hostname & Networking
  ############################################################
  networking.hostName = "dev";
  networking.networkmanager.enable = true;
hardware.bluetooth.enable = true;
services.blueman.enable = true;  # optional, adds the Blueman GUI manager

# K3s (Lightweight Kubernetes)
#services.k3s = {
#  enable = true;
#  role = "server";
#  extraFlags = toString [
#    "--disable=traefik"        # Disable traefik 
#    "--disable=metrics-server" # Disable metrics-server (causing API errors)
#    "--disable=servicelb"      # Disable service load balancer
#    "--write-kubeconfig-mode=0644"
#  ];
#};

  ############################################################
  ## Locale, Timezone, Keyboard
  ############################################################
  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS       = "fr_FR.UTF-8";
    LC_IDENTIFICATION= "fr_FR.UTF-8";
    LC_MEASUREMENT   = "fr_FR.UTF-8";
    LC_MONETARY      = "fr_FR.UTF-8";
    LC_NAME          = "fr_FR.UTF-8";
    LC_NUMERIC       = "fr_FR.UTF-8";
    LC_PAPER         = "fr_FR.UTF-8";
    LC_TELEPHONE     = "fr_FR.UTF-8";
    LC_TIME          = "fr_FR.UTF-8";
  };

  # Console keymap (TTY)
  console.keyMap = "fr";

  # X11 keyboard (Plasma fallback)
  services.xserver = {
    enable = true;          # keep X11 for Plasma fallback; Hyprland itself is Wayland
    xkb = {
      layout = "fr";
      variant = "azerty";
    };
  };

############################################################
## Display Manager & Desktop Environments
############################################################
# Login manager
services.displayManager = {
  sddm = {
    enable = true;
    wayland.enable = true;         # run SDDM on Wayland for best Hyprland compatibility
    
    # Add wallpaper here
    settings = {
      Theme = {
        Background = "/home/lys/Pictures/black.png";
        BackgroundFill = "aspect";
      };
    };
  };
  defaultSession = "hyprland";  # This needs to be at this level, not outside
};

# Keep Plasma 6 available as an alternative session
services.desktopManager.plasma6.enable = true;  # This should be separate, not nested

  ############################################################
  ## Hyprland (Wayland WM)
  ############################################################
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;          # run legacy X11 apps under Wayland
  };

  # Wayland portals (file pickers, screen sharing, open-with, etc.)
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  ############################################################
  ## Audio / Screen sharing (PipeWire)
  ############################################################
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;    # PulseAudio compatibility layer
    jack.enable = true;
  };

  ############################################################
  ## Graphics stack
  ############################################################
  # Modern graphics stack (Vulkan/VA-API where available)
  hardware.graphics.enable = true;
  # If your NixOS channel is older and this option is missing, use:
  # hardware.opengl.enable = true;

  ############################################################
  ## System Packages (desktop essentials for Hyprland)
  ############################################################
  environment.systemPackages = with pkgs; [
    # Bar / launcher / terminal
    waybar
    rofi-wayland
    kitty

    # Wallpapers + lock/idle
    hyprpaper
    hyprlock
    hypridle

    # Clipboard, screenshots, editors
    wl-clipboard
    grim
    slurp
    swappy            # simple screenshot editor
    satty             # annotate screenshots (optional)

    # Theming helpers
    nwg-look          # set GTK theme/icons on Wayland
    qt6ct             # tune Qt apps (set QT_QPA_PLATFORMTHEME=qt6ct if you use it)

    # Common utilities
	curl
	wget
	git
	vim
	unzip
	firefox
	obsidian
	docker-compose
	neovim
	vscode
	python3
	viu
	termpdfpy
	tree
	sqlite
	ani-cli
	kubectl
	minikube
	kubernetes
	gh
  	nodejs
  	nodePackages.npm
	claude-code
	opentofu
  ];

  # Prefer Wayland for Electron/Chromium-based apps (Chrome, Discord, VSCode, etc.)
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    # If you use qt6ct for Qt theming, uncomment:
    QT_QPA_PLATFORMTHEME = "kde";
  };

  ############################################################
  ## Printing
  ############################################################
  services.printing.enable = true;

  ############################################################
  ## Optional: Nix features (flakes/modern CLI)
  ############################################################
  # Not required for Hyprland, but handy:
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ############################################################
  ## Users
  ############################################################
  # Define users here if needed (example shown and commented out):
  # users.users.yourname = {
  #   isNormalUser = true;
  #   extraGroups = [ "networkmanager" "wheel" "docker" ]; # Enable sudo & network control
  #   packages = with pkgs; [ ];
  # };

  ############################################################
  ## Services you might add later
  ############################################################
  # services.openssh.enable = true;
users.users.lys = {
	isNormalUser = true;
	extraGroups = [ "wheel" "networkmanager" "docker" "k3s"];
	initialPassword = "ltbcuoviolyss";
};
}
