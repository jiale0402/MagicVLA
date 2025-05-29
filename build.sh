#!/bin/bash

# Check if a flag is provided
if [ -z "$1" ]; then
  echo "Usage: $0 [-c | -r | -i]"
  exit 1
fi

# Store current directory
CURRENT_DIR=$(pwd)

# Define ROS workspace directory
ROS_WS_DIR="$CURRENT_DIR/MagicSim/MagicRos"
ISAACLAB_DIR="$CURRENT_DIR/MagicSim/Third_Party/IsaacLab"
CUROBO_DIR="$CURRENT_DIR/MagicSim/Third_Party/curobo"
HOME_DIR="$HOME"
DOWNLOAD_DIR="$HOME/Downloads"
SIM_DIR="$CURRENT_DIR/MagicSim"
ISAAC_HOME="$HOME/isaacsim"

git submodule update --init
rm -rf "$SIM_DIR/.envrc"

# Check if ros_ws directory exists
if [ ! -d "$ROS_WS_DIR" ]; then
  echo "Directory 'ros_ws' does not exist in the current path."
  exit 1
fi

clean_ros_ws() {
  echo "Cleaning ROS workspace..."
  cd "$ROS_WS_DIR" || exit
  rm -rf build log install
  echo "ROS workspace cleaned."
}
build_ros_ws() {
  cd "$CURRENT_DIR" || exit
  echo "Building ROS workspace..."
  cd "$ROS_WS_DIR" || exit
  colcon build --symlink-install
  source install/setup.bash
  echo "ROS workspace built."
}


setup_base() {
  cd "$CURRENT_DIR" || exit
  echo "Setting up Base environment..."
  uv venv
  cd "$CURRENT_DIR" || exit
  source ".venv/bin/activate"
  uv sync
}




# Define setup functions
setup_robot() {
  cd "$CURRENT_DIR" || exit
  echo "Setting up robot..."
  # Add robot setup commands here
  echo "Setting up Robot environment..."
  uv sync --extra robot

  echo "Build ROS workspace..."
  build_ros_ws
  echo "Base environment setup completed."

  export OMNI_KIT_ACCEPT_EULA=YES

  echo "Install IsaacLab..."
  git submodule update --init --recursive
  cd "$ISAACLAB_DIR" || exit
  ./isaaclab.sh -i

  echo "Install Curobo..."
  cd "$CUROBO_DIR" || exit
  uv pip install -e . --no-build-isolation
  echo "Robot setup completed."
}

setup_rl() {
  cd "$CURRENT_DIR" || exit
  echo "Setting up RL..."
  echo "Setting up RL environment..."
  uv sync --extra rl
  uv pip install flash-attn --no-build-isolation

  echo "Build ROS workspace..."
  build_ros_ws
  echo "Base environment setup completed."

  echo "RL setup completed."
}

setup_all(){
  cd "$CURRENT_DIR" || exit
  echo "Setting up all..."
  echo "Setting up all environment..."
  uv sync --all-extras
  uv pip install flash-attn --no-build-isolation

  echo "Build ROS workspace..."
  build_ros_ws
  echo "Base environment setup completed."

  export OMNI_KIT_ACCEPT_EULA=YES

  echo "Install IsaacLab..."
  git submodule update --init --recursive
  cd "$ISAACLAB_DIR" || exit
  ./isaaclab.sh -i

  echo "Install Curobo..."
  cd "$CUROBO_DIR" || exit
  uv pip install -e . --no-build-isolation

  echo "All setup completed."
}



setup_dev() {
  cd "$CURRENT_DIR" || exit
  echo "Setting up develop environment..."
  echo "Setting up direnv"
  sudo apt-get install -y direnv
  #Add the following line at the end of the ~/.bashrc file:
  echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
  eval "$(direnv hook bash)"
  direnv allow

  echo "Setting up pre-commit"
  pre-commit install

  # Add dev setup commands here
  echo "Develop environment setup completed."
}

setup_robot_dev() {
  cd "$CURRENT_DIR" || exit
  echo "Setting up robot development environment..."

  # if the isaacsim directory not already exists
  if [ ! -d "$HOME_DIR/isaacsim" ] && [ ! -d "/isaac-sim" ]; then
    echo "IsaacSim directory does not exist, creating..."
    mkdir -p "$HOME_DIR/isaacsim"
    echo "Installing Isaacsim..."
    cd "$DOWNLOAD_DIR" || exit
    wget https://download.isaacsim.omniverse.nvidia.com/isaac-sim-standalone%404.2.0-rc.18%2Brelease.16044.3b2ed111.gl.linux-x86_64.release.zip
    unzip "isaac-sim-standalone%404.2.0-rc.18%2Brelease.16044.3b2ed111.gl.linux-x86_64.release.zip" -d "$HOME_DIR/isaacsim"
    cd "$HOME_DIR/isaacsim" || exit
    ./post_install.sh
  else
    # If one of the directories exists, set ISAAC_HOME accordingly
    if [ -d "$HOME/isaacsim" ]; then
        ISAAC_HOME="$HOME/isaacsim"
    else
        ISAAC_HOME="/isaac-sim"
    fi
  fi

  echo "Linking IsaacSim to Workspace..."
  cd "$CURRENT_DIR" || exit
  ln -s "$ISAAC_HOME" "$CURRENT_DIR/_isaac_sim"

  echo "Setting up Code Editor..."
  isaacsim-links --create
  echo "Robot development environment setup completed."
}




case "$1" in
  -c)
    clean_ros_ws

    ;;
  -r)
    build_ros_ws
    ;;
  -i)
    echo "Install robot, please enter 1; install rl, please enter 2; install all, please enter 3."
    read -r choice
    case "$choice" in
      1)
        setup_base
        setup_robot
        echo "Do you want to setup the robot development environment? (y/n)"
        read -r dev_choice
        if [ "$dev_choice" == "y" ]; then
          setup_dev
          setup_robot_dev
        elif [ "$dev_choice" != "n" ]; then
          echo "Invalid choice: $dev_choice"
          exit 1
        fi
        ;;
      2)
        setup_base
        setup_rl

        echo "Do you want to setup the development environment? (y/n)"
        read -r dev_choice
        if [ "$dev_choice" == "y" ]; then
          setup_dev
        elif [ "$dev_choice" != "n" ]; then
          echo "Invalid choice: $dev_choice"
          exit 1
        fi
        ;;
      3)
        setup_base
        setup_all
        echo "Do you want to setup the robot development environment? (y/n)"
        read -r dev_choice
        if [ "$dev_choice" == "y" ]; then
          setup_dev
          setup_robot_dev
        elif [ "$dev_choice" != "n" ]; then
          echo "Invalid choice: $dev_choice"
          exit 1
        fi
        ;;
      *)
        echo "Invalid Choice: $choice"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Invalid option: $1"
    echo "Usage: $0 [-c | -r | -i]"
    exit 1
    ;;
esac

# Return to the original directory
cd "$CURRENT_DIR" || exit
