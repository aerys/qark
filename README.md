Aerys Qark
==========


Description
-----------

**Qark is a simple and lightweight object encoder/decoder.**

Qark makes it easy to encode/decode a binary representation of an entire hierarchy of objects. This binary representation can then be saved to a file, sent over a network, etc…

Qark relies on simple generic types such as:

* signed integer (32 bits)
* unsigned integer (32 bits)
* float (32 bits)
* string (using UTF-8 encoding)
* boolean
* array
* object (or "associative array")
* bitmap data (32 bits ARGB values)

*Custom classes are also supported but will always be encoded as "objects" for the sake of interoperability.*

Qark will also compress the binary data using the `GZIP` or `DEFLATE` (http://www.ietf.org/rfc/rfc1951.txt) algorithm: the algorithm giving the lightest result will be selected automatically.

You can see Qark as an equivalent of JSON plus the following pros:

* minimalistic binary representation
* fast encoder/decoder
* fast and efficient data compression


Features
--------

* Qark gives you all the goodness of binary data without the hassle of creating your own proprietary format
* Qark is very simple and lightweight
* Qark can easily be ported to any language you might need in the future
* Qark supports the following languages:
	* ActionScript 3
	* PHP 5 (beta)


Usage
-----

Use Qark.encode to serialize an object:

	// encode a string
	data = Qark.encode("bar");
	// encode a number
	data = Qark.encode(42.42);
	// encode an object
	data = Qark.encode({test: "foo", bar: 42});
	// encode an array
	data = Qark.encode([1, 2, "three", 4.0]);

Use Qark.decode to deserialize an object:

	var data : ByteArray = Qark.encode({test: "foo", bar: 42});
	var object : Object = Qark.decode(data);

	// will trace "foo 42"
	trace(object.test, object.bar);

You can also encode your "custom" objects:

	// will trace "42"
	trace(Qark.decode(Qark.encode(new Point(10., 42.))).y);

Miscellaneous
-------------

### General ###

* Only "value objects", with properties which are both readable and writeable, will be properly encoded/decoded
* Support for bitmap data might be removed in future releases.

### ActionScript ###

* BitmapData objects are encoded as bitmap data

### PHP ###

* The GD extension is required to decode bitmap data properly.
* Only properly UTF-8 encoded strings (using utf8_encode) will be detected as strings
* Other strings will be encoded as bytes
* Bitmap data are converted to image ressources (using imagecreatetruecolor)
* Image ressources are encoded to bitmap data

### Behind the scene ###

The `encode` function follows this simple algorithm:

	encode object
	  if object is int or uint or float or string or boolean then
	    write object
	  else if object is array then
	    write length(object)
	    for each cell of object do
	      encode object[cell]
	  else if object is associative array then
	    write length(object)
	    for each property of object do
	      write property
	      encode object[property]


Contribute
----------

`aerys-qark` is MIT-licensed.  Make sure you tell us everything that's wrong!

Qark can be easily ported to other languages. Feel free to propose new implementations.

* [Source code](https://github.com/aerys/monitor)
* [Issue tracker](https://github.com/aerys/monitor/issues)
