find_package(react-native-vision-camera REQUIRED)

# Link all libraries together
target_link_libraries(
        ${PACKAGE_NAME}
        react-native-vision-camera::VisionCamera
)
