# --------------------------------------------------------------------------------------------
# according to man pkg-config
#  The package name specified on the pkg-config command line is defined to
#      be the name of the metadata file, minus the .pc extension. If a library
#      can install multiple versions simultaneously, it must give each version
#      its own name (for example, GTK 1.2 might have the package  name  "gtk+"
#      while GTK 2.0 has "gtk+-2.0").
#
# ${BIN_DIR}/unix-install/opencv.pc -> For use *with* "make install"
# -------------------------------------------------------------------------------------------
cmake_policy(SET CMP0026 OLD)

if(CMAKE_BUILD_TYPE MATCHES "Release")
  set(ocv_optkind OPT)
else()
  set(ocv_optkind DBG)
endif()

#build the list of opencv libs and dependencies for all modules
set(OpenCV_LIB_COMPONENTS "")
set(OpenCV_EXTRA_COMPONENTS "")
foreach(m ${OPENCV_MODULES_PUBLIC})
  list(INSERT OpenCV_LIB_COMPONENTS 0 ${${m}_MODULE_DEPS_${ocv_optkind}} ${m})
  if(${m}_EXTRA_DEPS_${ocv_optkind})
    list(INSERT OpenCV_EXTRA_COMPONENTS 0 ${${m}_EXTRA_DEPS_${ocv_optkind}})
  endif()
endforeach()

ocv_list_unique(OpenCV_LIB_COMPONENTS)
ocv_list_unique(OpenCV_EXTRA_COMPONENTS)
ocv_list_reverse(OpenCV_LIB_COMPONENTS)
ocv_list_reverse(OpenCV_EXTRA_COMPONENTS)


#set the components' libdir
set(OpenCV_libdir "lib")

list(LENGTH OpenCV_LIB_COMPONENTS _tmp)

if("${_tmp}" GREATER "0")
  list(GET OpenCV_LIB_COMPONENTS 0 _tmp)
  get_target_property(libpath ${_tmp} LOCATION_${CMAKE_BUILD_TYPE})
  #need better solution....
  if(libpath MATCHES "3rdparty")
    set(OpenCV_libdir "share/OpenCV/3rdparty/${OPENCV_LIB_INSTALL_PATH}")
  else()
    set(OpenCV_libdir "${OPENCV_LIB_INSTALL_PATH}")
  endif()
endif()


#build the list of components
set(OpenCV_LIB_COMPONENTS_ "")
foreach(CVLib ${OpenCV_LIB_COMPONENTS})

  get_target_property(_libpath ${CVLib} LOCATION_${CMAKE_BUILD_TYPE})
  get_filename_component(_libname "${_libpath}" NAME_WE)
  string(REGEX REPLACE "^lib" "" _libname "${_libname}")

  # wolrd is a special target whose its library should come first, especially for
  # static link.
  if("${CVLib}" MATCHES "world")
    set(OpenCV_LIB_COMPONENTS_ "-l${_libname} ${OpenCV_LIB_COMPONENTS_}")
  else()
    set(OpenCV_LIB_COMPONENTS_ "${OpenCV_LIB_COMPONENTS_} -l${_libname}")
  endif()

endforeach()

set(OpenCV_LIB_COMPONENTS "-L\${libdir} ${OpenCV_LIB_COMPONENTS_}")


# add extra dependencies required for OpenCV
if(OpenCV_EXTRA_COMPONENTS)
  foreach(extra_component ${OpenCV_EXTRA_COMPONENTS})

    if(extra_component MATCHES "^-[lL]")
      set(maybe_l_prefix "")
      set(libname "${extra_component}")
    elseif(extra_component MATCHES "[\\/]")
      get_filename_component(libname "${extra_component}" NAME_WE)
      get_filename_component(libdir "${extra_component}" DIRECTORY)
      string(REGEX REPLACE "^lib" "" libname "${libname}")
      set(maybe_l_prefix "-L${libdir} -l")
    else()
      set(maybe_l_prefix "-l")
      set(libname "${extra_component}")
    endif()

    set(OpenCV_LIB_COMPONENTS "${OpenCV_LIB_COMPONENTS} ${maybe_l_prefix}${libname}")

  endforeach()
endif()

#generate the .pc file
set(prefix      "${CMAKE_INSTALL_PREFIX}")
set(exec_prefix "\${prefix}")
set(libdir      "\${exec_prefix}/${OpenCV_libdir}")
set(includedir  "\${prefix}/${OPENCV_INCLUDE_INSTALL_PATH}")

if(INSTALL_TO_MANGLED_PATHS)
  set(OPENCV_PC_FILE_NAME "opencv-${OPENCV_VERSION}.pc")
else()
  set(OPENCV_PC_FILE_NAME opencv.pc)
endif()
configure_file("${OpenCV_SOURCE_DIR}/cmake/templates/opencv-XXX.pc.in"
               "${CMAKE_BINARY_DIR}/unix-install/${OPENCV_PC_FILE_NAME}"
               @ONLY)

if(UNIX AND NOT ANDROID)
  install(FILES ${CMAKE_BINARY_DIR}/unix-install/${OPENCV_PC_FILE_NAME} DESTINATION ${OPENCV_LIB_INSTALL_PATH}/pkgconfig COMPONENT dev)
endif()
