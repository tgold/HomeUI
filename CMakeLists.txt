cmake_minimum_required(VERSION 3.21)

project(HomeUI VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.5)

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
