FASL File Format
================

FASL is an acronim for "FASt Load". FASL format is not finalized and may be changed in the future.


Glossary
--------
* byte, just an 8-bit octet.
* integer, little-endian multibyte sequence with signaling high bit.
* longint_t, integer with unlimited accuracy.

FASL decoder is pretty simple and workable sample code for `fasl->sexp` and `sexp->fasl` can be found in the [special Ol branch](https://github.com/yuriy-chumak/ol/tree/bootstrapping/examples/bootstrapping).

### Integer's Encoding

All integers are encoded in a little-endian multibyte sequence with signaling high bit.
That means a continuous stream of bytes with the least significant 6 bits and the most highest (7th) bit as a sequence flag. The last byte of sequence must have the 7th bit set to zero.

In other words, you should read a byte, if high bit is zero then return a value, if high bit is set then use lower 7 bits as part of result and repeat with next byte.

Pseudocode:
```c
longint_t nat = 0;
unsigned char uch;

int i = 0;
do {
   uch = read_next_byte();
   nat |= (uch & 0b01111111) << i;
   i += (8-1);
} while (uch & 0b10000000);
return nat;
```

Format examples (first '0' means "number", second '0' means "positive integer", other numbers are the encoded integer):
```scheme
> (fasl-encode 1)
'(0 0 1)
> (fasl-encode 127)
'(0 0 127)
> (fasl-encode 128)
'(0 0 128 1)
> (fasl-encode 256)
'(0 0 128 2)
> (fasl-encode 11111111111111111111111111111111)
'(0 0 199 227 241 184 172 197 191 194 185 219 199 253 222 135 35)
> (fasl-decode '(0 0 199 227 241 184 172 197 191 194 185 219 199 253 222 135 35) #f)
11111111111111111111111111111111
```

Format
------

FASL data is a plain vector of tags with zero tag as end of stream.

```c
struct fasl_t
{
   tag_t items[N];
}
```

Every tag has type in a first byte and variable length data structure. All tag values except 0, 1, and 2 are reserved for future use and should be interpret as invalid.

```c
struct tag_t
{
   byte tag;
   switch {
      // tag == 0;
      struct eos_t {}

      // tag == 1;
      struct obj_t;

      // tag == 2:
      struct raw_t;
   }
}
```

### eos_t

Empty tag. End Of Stream indicator.

```c
struct eos_t {}
```

### raw_t

Bytevectors, ansi strings, inexact numbers... Any object that has no other objects included. For such objects predicate `raw?` returns #true.

```c
struct raw_t
{
   byte type;
   integer length;
   byte payload[length];
}
```

The example of decoded part of fasl image with raw_t records and it's binary representation, "3" is a `type-string`:
![](img/2022-12-19-21-51-40.png)

### obj_t

Any other object than raw. For such objects predicate `raw?` returns #false and predicate `reference?` returns #true. No values (small integers, constants, small ports, etc.) are allowed.

```c
struct obj_t
{
   byte type;
   integer count;
   item_t payload[count];
}
```

Every item_t is either integer or reference to the previously decoded object.

```c
struct item_t
{
   switch {
      struct value_t {
         byte flag = 0;
         byte type;
         integer value;
      }

      integer reference > 0;
   }
}
```

The example of decoded part of fasl image with 'reference' and it's binary representation, "3" is a `type-symbol`:
![](img/2022-12-19-23-06-48.png)

### notes

You can convert type value into typename using `typename` function. For example,
```scheme
> (typename 3)
'type-string
> (typename 18)
'type-closure
> (typename 63)
'type-constructor
```
