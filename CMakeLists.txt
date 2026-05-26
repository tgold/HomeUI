cmake_minimum_required(VERSION 3.21)

project(HomeUI VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.4 QUIET COMPONENTS Network Quick QuickControls2)
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

find_package(Qt6 6.4 QUIET COMPONENTS Mqtt)
set(HOMEUI_HAS_MQTT FALSE)
if(Qt6Mqtt_FOUND)
    set(HOMEUI_HAS_MQTT TRUE)
    message(STATUS "Qt6::Mqtt found - MQTT integration enabled")
else()
    message(WARNING
        "Qt6::Mqtt was not found - MQTT integration will be disabled.\n"
        "Debian / Raspberry Pi OS does not ship the Qt MQTT add-on in apt;\n"
        "run scripts/install-pi-deps.sh to build the matching qtmqtt release\n"
        "from source against the system Qt, or install qt6-mqtt-dev manually\n"
        "if a backport is available on your system."
    )
endif()

qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(homeui
    src/DashboardConfig.cpp
    src/DashboardConfig.h
    src/MjpegView.cpp
    src/MjpegView.h
    src/OpenHabClient.cpp
    src/OpenHabClient.h
    src/main.cpp
)

if(HOMEUI_HAS_MQTT)
    target_sources(homeui PRIVATE
        src/MqttClient.cpp
        src/MqttClient.h
    )
    target_compile_definitions(homeui PRIVATE HOMEUI_HAS_MQTT)
endif()

qt_add_qml_module(homeui
    URI HomeUI
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/ConfiguredPage.qml
        qml/components/ConfiguredPanel.qml
        qml/components/CameraTile.qml
        qml/components/ControlsPanel.qml
        qml/components/ControlTile.qml
        qml/components/DimmerTile.qml
        qml/components/EnergyPanel.qml
        qml/components/Format.js
        qml/components/MetricRow.qml
        qml/components/ModePanel.qml
        qml/components/MqttPanel.qml
        qml/components/PageDots.qml
        qml/components/RoomPanel.qml
        qml/components/SceneTile.qml
        qml/components/ShutterTile.qml
        qml/components/StatusBar.qml
        qml/components/ThermostatTile.qml
)

target_include_directories(homeui
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(homeui
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Network
)

if(HOMEUI_HAS_MQTT)
    target_link_libraries(homeui PRIVATE Qt6::Mqtt)
endif()

set_target_properties(homeui PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
)

install(TARGETS homeui
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES config/dashboard.json
    DESTINATION ${CMAKE_INSTALL_SYSCONFDIR}/homeui
)
