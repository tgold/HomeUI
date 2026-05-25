cmake_minimum_required(VERSION 3.21)

project(HomeUI VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.4 QUIET COMPONENTS Quick QuickControls2)
if(NOT Qt6_FOUND)
    message(FATAL_ERROR
        "Qt 6.4 development files were not found.\n"
        "\n"
        "On Raspberry Pi OS / Debian / Ubuntu, install the required Qt packages first:\n"
        "  sudo apt update\n"
        "  sudo apt install g++ cmake qt6-base-dev qt6-declarative-dev \\\n"
        "    qml6-module-qtquick qml6-module-qtquick-controls \\\n"
        "    qml6-module-qtquick-templates qml6-module-qtquick-layouts \\\n"
        "    qml6-module-qtquick-window qml6-module-qtqml-workerscript\n"
        "\n"
        "Then re-run:\n"
        "  cmake -S . -B build-gcc -DCMAKE_CXX_COMPILER=g++\n"
        "\n"
        "If Qt was installed from the Qt online installer instead of apt, pass its prefix:\n"
        "  cmake -S . -B build-gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x/gcc_arm64\n"
    )
endif()

qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(homeui
    src/main.cpp
)

qt_add_qml_module(homeui
    URI HomeUI
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/CameraTile.qml
        qml/components/ControlTile.qml
        qml/components/EnergyPanel.qml
        qml/components/MetricRow.qml
        qml/components/ModePanel.qml
        qml/components/PageDots.qml
        qml/components/RoomPanel.qml
        qml/components/StatusBar.qml
)

target_link_libraries(homeui
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
)

set_target_properties(homeui PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
)

install(TARGETS homeui
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
