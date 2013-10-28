A more convenient form of the type info in wxc.

As the `wxc_types.h` file notes:
````
 Types: we use standard pre-processor definitions to add more
 type information to the C signatures. These 'types' can be
 either read by other tools to automatically generate a marshalling
 layer for foreign languages, or you can define the macros in such
 a way that they contain more type information while compiling the
 library itself.
````

However, parsing the header files to read back this information is tedious, and
needs to be done by every language binding. This project attempts to retrieve
the class and method hierarchy, and provide a conveniently machine-readable
mapping from class.method to C function. The idea is that other languages can
use SWIG or equivalent to generate the low-level bindings to the wxc C
functions, and then use the data structures from wxc-parsed to quickly generate
a higher-level OO layer on top of that.
