#cython: language_level=3
from libc.stdio cimport *
from libc.string cimport *
from libc.stdlib cimport malloc, free
from cpython cimport PyObject, PyList_New, PyList_SetItem
cimport numpy as np

# essential for setting up NumPy-C API
np.import_array()

cdef extern from "src/mib_header_MQ1.h":
    ctypedef struct mq1s:
      unsigned int sequence_number
      unsigned int exposure_time_ns

    ctypedef struct mq1q:
      unsigned int sequence_number
      unsigned int exposure_time_ns

cdef extern from "src/read_mq1_headers.h":
    ctypedef struct MQ1_fields:
      unsigned int max_length
      unsigned int* sequence_number
      unsigned int* header_bytes
      unsigned int* num_chips
      unsigned int* det_x
      unsigned int* det_y
      char* pixel_depth
      char* sensor_layout
      char* chip_select
      char* timestamp
      double* exposure_time_s
      unsigned int* counter
      unsigned int* colour_mode
      unsigned int* gain_mode
      float* threshold
      char* header_extension_id
      char* extended_timestamp
      unsigned int* exposure_time_ns
      unsigned int* bit_depth

    MQ1_fields allocate_MQ1_fields(unsigned int nheaders)

    void deallocate_MQ1_fields(MQ1_fields mq1_fields)

    unsigned int mq1_single_from_file(
            FILE* mib_ptr,
            unsigned int nheaders,
            unsigned int detector_size,
            mq1s* mq1s_h,
            MQ1_fields* mq1_fields,
            )
    unsigned int mq1_quad_from_file(
            FILE* mib_ptr,
            unsigned int nheaders,
            unsigned int detector_size,
            mq1q* mq1q_h,
            MQ1_fields* mq1_fields,
            )

cdef extern from "src/mib_utils.h":
    void header_meta_from_first(FILE* mib_ptr,
                                char* header_id,
                                unsigned int* header_bytes,
                                unsigned int* num_chips,
                                unsigned int* det_x,
                                unsigned int* det_y
                                )
    unsigned int num_of_headers(FILE* mib_ptr,
                                const unsigned int stride
                                )

cdef extern from "src/mib_macros.h":
    int MQ1_CHAR_LEN_PIXEL_DEPTH # 4
    int MQ1_CHAR_LEN_SENSOR_LAYOUT # 7
    int MQ1_CHAR_LEN_CHIP_SELECT # 3
    int MQ1_CHAR_LEN_TIMESTAMP # 27
    int MQ1_FLOAT_LEN_THRESHOLD # 8
    int MQ1_CHAR_LEN_HEADER_EXTENSION_ID # 5
    int MQ1_CHAR_LEN_EXTENDED_TIMESTAMP # 31

cdef extern from "Python.h":
    PyObject* Py_BuildValue(const char* format, ...)

cdef npy_array_from_field(
        void* field,
        int nd,
        np.npy_intp* dims,
        int typenum):
    # 'field' is on the heap and it will be freed
    # so to avoid NumPy array pointing to invalid memory,
    # a copy of the array pointing to the field (in heap) is made
    new_arr = np.PyArray_SimpleNew(nd, dims, typenum)
    np.PyArray_CopyInto(new_arr,
                        np.PyArray_SimpleNewFromData(nd,
                                                     dims,
                                                     typenum,
                                                     field))

    return new_arr

cdef str_list_from_field(
        char* field,
        unsigned int str_len,
        unsigned int nfield):
    # if the char field is abc\0def\0ghi\0
    # and str_len = 4, nfield = 3
    # then str_list will be ["abc", "def", "ghi"]

    # prevent modification by strtok
    cdef char* copy = strdup(field)

    str_list = PyList_New(nfield)
    for k in range(nfield):
        PyList_SetItem(str_list, k, <object>Py_BuildValue("s#", strtok(copy, "\0"), str_len-1))

    free(copy)
    copy = NULL

    return str_list

def mib_props(mib_path, max_header_index=-1, **kwargs):
    """Return a dictionary for
    """
    # separate to avoid creation of temporary Python object
    fbytes = mib_path.encode()
    cdef char* mib_filename = fbytes

    cdef FILE* f
    cdef char header_id[4]
    cdef unsigned int header_bytes, num_chips, det_x, det_y, frame_stride, num_headers, num_parsed
    cdef long int max_hidx = max_header_index
    cdef mq1s* mq1s_ptr
    cdef mq1q* mq1q_ptr
    cdef MQ1_fields mq1_fields
    cdef np.npy_intp field_length

    if max_hidx == 0:
        msg = (f"max_header_index cannot be zero, use any negative number "
               "to parse all headers in the MIB file")
        raise ValueError(msg)

    f = fopen(mib_filename, "rb")
    if (f == NULL):
        msg = f"Failed to open the MIB file {mib_path}"
        raise FileNotFoundError(msg)

    header_meta_from_first(f,
                           header_id,
                           &header_bytes,
                           &num_chips,
                           &det_x,
                           &det_y
                           )

    # check if this is from 'MQ1'
    if (header_id != b"MQ1"):
        fclose(f)
        msg = "Only the version 'MQ1' is currently supported"
        raise ValueError(msg)

    # unlikely to overflow
    frame_stride = header_bytes + det_x * det_y

    # determine the number of headers/frames in the MIB file
    # it returns 0 if it fails to determine
    num_headers = num_of_headers(f, frame_stride)
    if (num_headers == 0):
        fclose(f)
        msg = "Failed to determine the number of headers in the MIB file"
        raise RuntimeError(msg)
    if max_hidx > 0:
        if max_hidx < num_headers:
            num_headers = max_hidx
        else:
            print(f"warning: the specified max_header_index ({max_hidx}) is "
                  f"larger than the total number of header(s) ({num_headers}) "
                  f"in the MIB file. Only the first {num_headers} "
                   "header(s) will be parsed.")

    # allocate memory for different fields
    mq1_fields = allocate_MQ1_fields(num_headers)

    # allocate memory
    if (num_chips == 1):
        # Single
        mq1s_ptr = <mq1s*>malloc(sizeof(mq1s) * num_headers)

        if (mq1s_ptr ==  NULL):
            deallocate_MQ1_fields(mq1_fields)
            fclose(f)
            msg = "Error when allocating memory to single header pointer"
            raise MemoryError(msg)

        num_parsed = mq1_single_from_file(f,
                                          num_headers,
                                          det_x*det_y,
                                          mq1s_ptr,
                                          &mq1_fields
                                          )

        # free memory
        free(mq1s_ptr)
        mq1s_ptr = NULL
    elif (num_chips == 4):
        # Quad
        mq1q_ptr = <mq1q*>malloc(sizeof(mq1q) * num_headers)

        if (mq1q_ptr ==  NULL):
            deallocate_MQ1_fields(mq1_fields)
            fclose(f)
            msg = "Error when allocating memory to quad header pointer"
            raise MemoryError(msg)

        num_parsed = mq1_quad_from_file(f,
                                        num_headers,
                                        det_x*det_y,
                                        mq1q_ptr,
                                        &mq1_fields
                                        )

        # free memory
        free(mq1q_ptr)
        mq1q_ptr = NULL
    else:
        deallocate_MQ1_fields(mq1_fields)
        fclose(f)
        raise RuntimeError(f"Chip number {num_chips} not supported")

    # check status of parsing header
    # the mq1_XXX_from_file return 0 upon unsuccessful parsing
    # otherwise it returns the number of parsed headers
    if (num_parsed == 0):
        deallocate_MQ1_fields(mq1_fields)
        fclose(f)
        msg = "Error when parsing the header"
        raise RuntimeError(msg)

    # close the file
    if (fclose(f) == EOF):
        deallocate_MQ1_fields(mq1_fields)
        raise RuntimeError(f"Failed top close the MIB file {mib_path}")

    # compose the return depending on kwargs, horrible
    field_length = <np.npy_intp> num_headers
    cdef np.npy_intp[2] thresh_dims= [num_headers, MQ1_FLOAT_LEN_THRESHOLD]
    ret = {}
    if kwargs.get("sequence_number"):
        ret["sequence_number"] = npy_array_from_field(<void*>mq1_fields.sequence_number, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("header_bytes"):
        ret["header_bytes"] = npy_array_from_field(<void*>mq1_fields.header_bytes, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("num_chips"):
        ret["num_chips"] = npy_array_from_field(<void*>mq1_fields.num_chips, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("det_x"):
        ret["det_x"] = npy_array_from_field(<void*>mq1_fields.det_x, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("det_y"):
        ret["det_y"] = npy_array_from_field(<void*>mq1_fields.det_y, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("pixel_depth"):
        # pixel_depth is char[4]
        ret["pixel_depth"] = str_list_from_field(mq1_fields.pixel_depth, MQ1_CHAR_LEN_PIXEL_DEPTH, num_headers)
    if kwargs.get("sensor_layout"):
        # sensor_layout is char[7]
        ret["sensor_layout"] = str_list_from_field(mq1_fields.sensor_layout, MQ1_CHAR_LEN_SENSOR_LAYOUT, num_headers)
    if kwargs.get("chip_select"):
        # chip_select is char[3]
        ret["chip_select"] = str_list_from_field(mq1_fields.chip_select, MQ1_CHAR_LEN_CHIP_SELECT, num_headers)
    if kwargs.get("timestamp"):
        # timestamp is char[27]
        ret["timestamp"] = str_list_from_field(mq1_fields.timestamp, MQ1_CHAR_LEN_TIMESTAMP, num_headers)
    if kwargs.get("exposure_time_s"):
        ret["exposure_time_s"] = npy_array_from_field(<void*>mq1_fields.exposure_time_s, 1, &field_length, np.NPY_DOUBLE)
    if kwargs.get("counter"):
        ret["counter"] = npy_array_from_field(<void*>mq1_fields.counter, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("colour_mode"):
        ret["colour_mode"] = npy_array_from_field(<void*>mq1_fields.colour_mode, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("gain_mode"):
        ret["gain_mode"] = npy_array_from_field(<void*>mq1_fields.gain_mode, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("threshold"):
        ret["threshold"] = npy_array_from_field(<void*>mq1_fields.threshold, 2, thresh_dims, np.NPY_FLOAT32)
    if kwargs.get("header_extension_id"):
        # header_extension_id is char[5]
        ret["header_extension_id"] = str_list_from_field(mq1_fields.header_extension_id, MQ1_CHAR_LEN_HEADER_EXTENSION_ID, num_headers)
    if kwargs.get("extended_timestamp"):
        # extended_timestamp is char[31]
        ret["extended_timestamp"] = str_list_from_field(mq1_fields.extended_timestamp, MQ1_CHAR_LEN_EXTENDED_TIMESTAMP, num_headers)
    if kwargs.get("exposure_time_ns"):
        ret["exposure_time_ns"] = npy_array_from_field(<void*>mq1_fields.exposure_time_ns, 1, &field_length, np.NPY_UINT32)
    if kwargs.get("bit_depth"):
        ret["bit_depth"] = npy_array_from_field(<void*>mq1_fields.bit_depth, 1, &field_length, np.NPY_UINT32)

    # free MQ1 fields memory
    deallocate_MQ1_fields(mq1_fields)

    return ret
