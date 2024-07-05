# Frame header parser for Merlin Single/Quad file (.mib)

The repository contains scripts to extract information from the frame header in
files from the Merlin Single/Quad system (usually with a .mib extension) by
Quantum Detectors.

There are some .mib file reader such as
[rosettasciio](https://github.com/hyperspy/rosettasciio) and
[read\_mib](https://github.com/matkraj/read_mib), which contains partial header
parser for .mib file. The motivation of this repository is to provide a full
header parser for a .mib file.

## Installation

The core scripts are written in C to allow interfacing by different languages.
The repository currently contains a Python wrapper (`mib_prop.pyx`).

### Python (as C extension)

For Python, after cloning the repository, you can produce the C extension by

```console
python setup.py build_ext --inplace
```

(this also requires NumPy to be installed)

It will produce a shared library (a `.so` file on Linux, `.pyd` on Windows) and
you can import it as a normal Python module:

```python
from mib_prop import mib_props
```

## Usage

### Python

The Python wrapper provides the function `mib_props`. For the simplest usage,
it takes one argument which is the path of your .mib file, and return a
dictionary. If you do

```python
from mib_prop import mib_props

mib_properties = mib_props("my_mib_file.mib")
```

You will find `mib_properties` an empty dictionary which is pointless.
Instead, if you do

```python
mib_properties = mib_props("my_mib_file.mib",
                           sequence_number=True
                           )
```

When you examine `mib_properties`, depending on how many frames are in your
.mib file, you will see something similar to this:

```python
{'sequence_number': array([    1,     2,     3, ..., 65534, 65535, 65536],
        dtype=uint32)}
```

With `sequence_number=True`, it extracts the sequence numbers from all the
frame header in the .mib file. You can control how many frame header to parse
by passing the number to the parameter `max_header_index`:

```python
mib_properties = mib_props("my_mib_file.mib",
                           max_header_index=10,
                           sequence_number=True
                           )
```

When you examine `mib_properties`, it only shows the values of sequence number
from the first 10 frames:

```python
{'sequence_number': array([ 1,  2,  3,  4,  5,  6,  7,  8,  9, 10],
        dtype=uint32)}
```

You can set the following arguments to `True` to return the corresponding
field in the frame headers:

- `sequence_number` (header ID)
- `header_bytes` (acquisition sequence number)
- `num_chips` (data offset)
- `det_x` (pixel dimension X)
- `det_y` (pixel dimension Y)
- `pixel_depth` (pixel depth in file)
- `sensor_layout` (sensor layout)
- `chip_select` (chip select)
- `timestamp` (time stamp)
- `exposure_time_s` (acquisition shutter time in s)
- `counter` (counter)
- `colour_mode` (colour mode)
- `gain_mode` (gain mode)
- `threshold` (threshold, 0-7)
- `header_extension_id` (header extension ID)
- `extended_timestamp` (extended time stamp)
- `exposure_time_ns` (acquisition shutter time in ns)
- `bit_depth` (counter depth)

Please refer to the MerlinEM User Manual for details. Currently information
from the DACs are not supported by the Python wrapper.

### C

There are two main functions which you will be using, for parsing Merlin Single
.mib file, you will use the `mq1_single_from_file` function; for parsing Merlin
Quad .mib file, you will use the `mq1_quad_from_file`. Both are in the file
`read_mq1_headers.c`. The only difference between them in the frame header is
the number of DACs parsed.

The signatures of them are:
```C
unsigned int mq1_single_from_file(FILE* mib_ptr,
                                  unsigned int nheaders,
                                  unsigned int detector_frame_bytes,
                                  mq1s* mq1s_h,
                                  MQ1_fields* mq1_fields
                                  )

unsigned int mq1_quad_from_file(FILE* mib_ptr,
                                unsigned int nheaders,
                                unsigned int detector_frame_bytes,
                                mq1q* mq1q_h,
                                MQ1_fields* mq1_fields
                                )
```

`mib_ptr` is the file pointer to your .mib file; `nheaders` is the number of
frame headers to be parsed; `detector_frame_bytes` is the number of bytes of
the frame (excluding the header); `mq1s_h` and `mq1q_h` is the pointer to the
struct with members corresponding to the frame header frame. The structs `mq1s`
and `mq1q` are defined in the `mib_header_MQ1.h` file; `mq1_fields` is a
pointer to the struct containing the fields in the .mib file. The struct
`MQ1_fields` is defined in the file `read_mq1_headers.h`. Both functions return
the number of frame headers that are successfully parsed (0 if no header is
parsed).

## API

### read\_mq1\_headers.c

#### `mq1_single_from_file`

The signature is

```C
unsigned int mq1_single_from_file(FILE* mib_ptr,
                                  unsigned int nheaders,
                                  unsigned int detector_frame_bytes,
                                  mq1s* mq1s_h,
                                  MQ1_fields* mq1_fields
                                  )
```

The function parses frame headers from a Merlin Single .mib file.

- *mib_ptr*

The file pointer to the .mib file.

- *nheaders*

The number of frame headers to be parsed.

- *detector_frame_bytes*

The number of bytes of the frame (excluding the header). This is almost always
(the number of pixel in X) x (the number of pixel in Y) x (pixel depth).

- *mq1s_h*

The pointer to the struct `mq1s`, which is defined in `mib_header_MQ1.h`. The
members are the field for Merlin Single system.

- *mq1_fields*

The pointer to the struct `MQ1_field`, which is defined in
`read_mq1_headers.h`. The members are pointers to the parsed fields.

#### `mq1_quad_from_file`

The signature is

```C
unsigned int mq1_quad_from_file(FILE* mib_ptr,
                                unsigned int nheaders,
                                unsigned int detector_frame_bytes,
                                mq1q* mq1q_h,
                                MQ1_fields* mq1_fields
                                )
```

The function parses frame headers from a Merlin Quad .mib file.

- *mib_ptr*

The file pointer to the .mib file.

- *nheaders*

The number of frame headers to be parsed.

- *detector_frame_bytes*

The number of bytes of the frame (excluding the header). This is almost always
(the number of pixel in X) x (the number of pixel in Y) x (pixel depth).

- *mq1q_h*

The pointer to the struct `mq1q`, which is defined in `mib_header_MQ1.h`. The
members are the field for Merlin Quad system.

- *mq1_fields*

The pointer to the struct `MQ1_field`, which is defined in
`read_mq1_headers.h`. The members are pointers to the parsed fields.

#### `allocate_MQ1_fields`

The signature is

```C
MQ1_fields allocate_MQ1_fields(unsigned int nheaders)
```

The function allocates memory to each member which stores each field of the
frame header. Please use the function `deallocate_MQ1_fields` to correctly free
the memory.

- *nheaders*

The number of each field to be allocated.

#### `deallocate_MQ1_fields`

The signature is

```C
void deallocate_MQ1_fields(MQ1_fields mq1_fields)
```

The function frees the memory allocated to `mq1_fields` by
`allocate_MQ1_fields`.

- *mq1_fields*

The `MQ1_fields` to be freed.

#### `fill_MQ1_single_fields`

The signature is

```C
void fill_MQ1_single_fields(MQ1_fields* mq1_field,
                            unsigned int index,
                            mq1s mq1_h
                            )
```

The function populates the fields `mq1_field` by the information from Merlin
Single header in `mq1_h`.

- *mq1_field*

The pointer to `MQ1_fields` which stores each field of the frame header.

- *index*

The position to be stored.

- *mq1_h*

The `mq1s` Merlin Single header.

#### `fill_MQ1_quad_fields`

The signature is

```C
void fill_MQ1_quad_fields(MQ1_fields* mq1_field,
                          unsigned int index,
                          mq1q mq1_h
                          )
```

The function populates the fields `mq1_field` by the information from Merlin
Quad header in `mq1_h`.

- *mq1_field*

The pointer to `MQ1_fields` which stores each field of the frame header.

- *index*

The position to be stored.

- *mq1_h*

The `mq1q` Merlin Quad header.

### mq1\_single.c

#### `parse_mq1_single`

The signature is

```C
void parse_mq1_single(const char* header,
                      mq1s* mq1_single
                      )
```

The function parses a frame header from Merlin Single system and stores the
fields into `mq1_single`.

- *header*

A Merlin Single frame header.

- *mq1_single*

The pointer to store the fields.

#### `print_single_mib_header`

The signature is

```C
void print_single_mib_header(mq1s header)
```

The function prints the contents of a Merlin Single header.

- *header*

The Merlin Single header to be printed.

### mq1\_quad.c

#### `parse_mq1_quad`

The signature is

```C
void parse_mq1_quad(const char* header,
                    mq1q* mq1_quad
                    )
```

The function parses a frame header from Merlin Quad system and stores the
fields into `mq1_quad`.

- *header*

A Merlin Quad frame header.

- *mq1_quad*

The pointer to store the fields.

#### `print_quad_mib_header`

The signature is

```C
void print_quad_mib_header(mq1q header)
```

The function prints the contents of a Merlin Quad header.

- *header*

The Merlin Quad header to be printed.

### mib\_utils.c

#### `num_of_headers`

The signature is

```C
unsigned int num_of_headers(FILE* mib_ptr,
                            const unsigned int stride
                            )
```

The function returns the total number of frame headers in the .mib file.

- *mib_ptr*

The file pointer to the .mib file.

- *stride*

The number of bytes of a frame (header and detector data).

#### `header_meta_from_first`

The signature is

```C
void header_meta_from_first(FILE* mib_ptr,
                            char* header_id,
                            unsigned int* header_bytes,
                            unsigned int* num_chips,
                            unsigned int* det_x,
                            unsigned int* det_y,
                            char* pixel_depth
                            )
```

The function parses the first frame header and store some preliminary
information such as header ID, number of bytes of the header, number of chips,
pixel size in X and Y, and pixel depth.

- *mib_ptr*

The file pointer to the .mib file.

- *header_id*

The header ID.

- *header_bytes*

The pointer to the number of bytes.

- *num_chips*

The pointer to the number of chips.

- *det_x*

The pointer to the number of pixel in X.

- *det_y*

The pointer to the number of pixel in Y.

- *pixel_depth*

The pixel depth.

## Contributing

Contribution is very welcomed. Please use the [issue
page](https://github.com/ePSIC-DLS/mib_props/issues) to report any
bug and missing feature.

## Acknowledgements

The partial .mib header parser in
[rosettasciio](https://github.com/hyperspy/rosettasciio) and
[read\_mib](https://github.com/matkraj/read_mib) provides a starting point for
implementing the present full .mib header parser.

## Licence

MIT
