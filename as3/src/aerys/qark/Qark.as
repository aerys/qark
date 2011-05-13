package aerys.qark
{
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.describeType;
	import flash.utils.getQualifiedClassName;

	public class Qark
	{
		private static const MAGIC				: uint	= 0x3121322b;

		private static const FLAG_NONE			: uint	= 0;
		private static const FLAG_GZIP			: uint	= 1;
		private static const FLAG_DEFLATE		: uint	= 2;

		private static const TYPE_CUSTOM		: uint	= 0;
		private static const TYPE_OBJECT		: uint	= 1;
		private static const TYPE_ARRAY			: uint	= 2;
		private static const TYPE_INT			: uint	= 3;
		private static const TYPE_UINT			: uint	= 4;
		private static const TYPE_FLOAT			: uint	= 5;
		private static const TYPE_STRING		: uint	= 6;
		private static const TYPE_BYTES			: uint	= 7;
		private static const TYPE_BOOLEAN		: uint	= 8;
		private static const TYPE_BITMAP_DATA	: uint	= 9;


		private static const ENCODERS		: Array		= [encodeCustomObject,
														   encodeObject,
														   encodeArray,
														   encodeInteger,
														   encodeUnsignedInteger,
														   encodeFloat,
														   encodeString,
														   encodeBytes,
														   encodeBoolean,
														   encodeBitmapData];

		private static const DECODERS		: Array		= [decodeCustomObject,
														   decodeObject,
														   decodeArray,
														   decodeInteger,
														   decodeUnsignedInteger,
														   decodeFloat,
														   decodeString,
														   decodeBytes,
														   decodeBoolean,
														   decodeBitmapData];

		private static function getType(source : *) : int
		{
			if (source is int)
				return TYPE_INT;
			if (source is uint)
				return TYPE_UINT;
			if (source is Number)
				return TYPE_FLOAT;
			if (source is String)
				return TYPE_STRING;
			if (source is Array)
				return TYPE_ARRAY;
			if (source is ByteArray)
				return TYPE_BYTES;
			if (source is Boolean)
				return TYPE_BOOLEAN;
			if (source is BitmapData)
				return TYPE_BITMAP_DATA;
			if (getQualifiedClassName(source) == "Object")
				return TYPE_OBJECT;

			return TYPE_CUSTOM;
		}

		/**
		 * Encode an object. This object can be any "simple" type such as:
		 * <ul>
		 * <li>int</li>
		 * <li>uint</li>
		 * <li>Number</li>
		 * <li>String</li>
		 * <li>Boolean</li>
		 * <li>Array</li>
		 * <li>Object</li>
		 * <li>ByteArray</li>
		 * <li>BitmapData</li>
		 * </ul>
		 * <p>Custom classes are also supported. However, only "value objects"
		 * with valid getter/setter public members will be properly encoded.</p>
		 *
		 * <p>Encoding is done as follow:</p>
		 * <ul>
		 * <li>if the object as a "simple" type
		 * it will be encoded directly</li>
		 * <li>else, introspection will be used to
		 * list the public properties of the custom class to determine what
		 * can be encoded. All those properties will be encoded as a single
		 * Object value and will be decoded as such.</li>
		 * </ul>
		 *
		 * <p>The bytes are then compressed using the GZIP or DEFLATE
		 * (http://www.ietf.org/rfc/rfc1951.txt) algorithm:
		 * the algorithm giving the lightest output is selected.</p>
		 *
		 * @param source The object to encode.
		 * @return The resulting bytes in a ByteArray.
		 *
		 */
		public static function encode(source : *) : ByteArray
		{
			var result	: ByteArray	= new ByteArray();
			var data 	: ByteArray = new ByteArray();
			
			result.endian = Endian.LITTLE_ENDIAN;
			data.endian = Endian.LITTLE_ENDIAN;

			result.writeInt(MAGIC);

			encodeRecursive(source, data);
			data.position = 0;

			var size 			: int 	= data.length;
			var compressedSize	: int	= 0;
			var deflatedSize	: int	= 0;

			data.deflate();
			deflatedSize = data.length;
			data.inflate();

			data.compress();
			compressedSize = data.length;

			if (compressedSize < size && compressedSize < deflatedSize)
			{
				result.writeByte(FLAG_GZIP);
			}
			else if (deflatedSize < size && deflatedSize < compressedSize)
			{
				data.uncompress();
				data.deflate();
				result.writeByte(FLAG_DEFLATE);
			}
			else
			{
				data.uncompress();
				result.writeByte(FLAG_NONE);
			}

			result.writeBytes(data);
			result.position = 0;

			return result;
		}

		/**
		 * Decode bytes resulting from the Qark.encode method and return the
		 * corresponding object.
		 *
		 * @param source The bytes to decode.
		 * @return The decoded object.
		 *
		 */
		public static function decode(source : ByteArray) : *
		{
			source.endian = Endian.LITTLE_ENDIAN;
		
			var magic : uint	= source.readInt();

			if (magic != MAGIC)
				return null;

			var flags 	: uint		= source.readByte();
			var data	: ByteArray	= new ByteArray();

			source.readBytes(data);

			if (flags & FLAG_DEFLATE)
				data.inflate();
			else if (flags & FLAG_GZIP)
				data.uncompress();

			return decodeRecursive(data);
		}

		public static function encodeRecursive(source : *, target : ByteArray) : void
		{
			var flag : int = getType(source);

			target.writeByte(flag);
			ENCODERS[flag].call(null, source, target);
		}

		public static function decodeRecursive(source : ByteArray) : *
		{
			var flag : uint = source.readByte();

			return DECODERS[flag].call(null, source);
		}

		private static function encodeObject(source : Object, target : ByteArray) : void
		{
			var start	: int = target.position;
			var length 	: int = 0;
			var propertyName : String = null;

			target.position += 2;

			for (propertyName in source)
			{
				encodeString(propertyName, target);
				encodeRecursive(source[propertyName], target);

				++length;
			}

			var stop : int = target.position;

			target.position = start;
			target.writeShort(length);
			target.position = stop;
		}

		private static function decodeObject(source : ByteArray, target : Object = null) : Object
		{
			var length	: int		= source.readShort();

			target ||= new Object();

			for (; length > 0; --length)
				target[decodeString(source)] = decodeRecursive(source);

			return target;
		}

		private static function encodeArray(source : Array, target : ByteArray) : void
		{
			var length : int = source.length;

			target.writeShort(length);

			for (var i : int = 0; i < length; ++i)
				encodeRecursive(source[i], target);
		}

		private static function decodeArray(source : ByteArray) : Array
		{
			var array : Array = new Array();

			for (var length : int = source.readShort(); length > 0; --length)
				array.push(decodeRecursive(source));

			return array;
		}

		private static function encodeString(source : String, target : ByteArray) : void
		{
			target.writeUTF(source);
		}

		private static function decodeString(source : ByteArray) : String
		{
			return source.readUTF();
		}

		private static function encodeInteger(source : int, target : ByteArray) : void
		{
			target.writeInt(source);
		}

		private static function decodeInteger(source : ByteArray) : int
		{
			return source.readInt();
		}

		private static function encodeUnsignedInteger(source : uint, target : ByteArray) : void
		{
			target.writeUnsignedInt(source);
		}

		private static function decodeUnsignedInteger(source : ByteArray) : uint
		{
			return source.readUnsignedInt();
		}

		private static function encodeFloat(source : Number, target : ByteArray) : void
		{
			target.writeFloat(source);
		}

		private static function decodeFloat(source : ByteArray) : Number
		{
			return source.readFloat();
		}

		private static function encodeBytes(source : ByteArray, target : ByteArray) : void
		{
			target.writeInt(source.length);
			target.writeBytes(source);
		}

		private static function decodeBytes(source : ByteArray) : ByteArray
		{
			var ba : ByteArray = new ByteArray();
			var length : int = source.readInt();

			source.readBytes(source, 0, length);

			return ba;
		}

		private static function encodeBoolean(source : Boolean, target : ByteArray) : void
		{
			target.writeByte(source ? 1 : 0);
		}

		private static function decodeBoolean(source :ByteArray) : Boolean
		{
			return source.readByte() == 1;
		}

		private static function encodeCustomObject(source : Object, target : ByteArray) : void
		{
			var variables	: XMLList = describeType(source).variable;
			var object		: Object = new Object();

			for each (var variable : XML in variables)
			{
				var propertyName : String = variable.@name;

				object[propertyName] = source[propertyName];
			}

			encodeObject(object, target);
		}

		private static function decodeCustomObject(source : ByteArray) : Object
		{
			return decodeObject(source);
		}

		private static function encodeBitmapData(source : BitmapData, target : ByteArray) : void
		{
			var ba : ByteArray = source.getPixels(source.rect);

			target.writeShort(source.width);
			target.writeShort(source.height);

			encodeBytes(ba, target);
		}

		private static function decodeBitmapData(source : ByteArray) : BitmapData
		{
			var bmp : BitmapData = new BitmapData(source.readShort(),
												  source.readShort());

			bmp.setPixels(bmp.rect, decodeBytes(source));

			return bmp;
		}
	}
}
