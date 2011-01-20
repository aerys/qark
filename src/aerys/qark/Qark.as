package aerys.qark
{
	import flash.net.FileReference;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;

	public class Qark
	{
		private static const FLAG_OBJECT		: int		= 0;
		private static const FLAG_ARRAY			: int		= 1;
		private static const FLAG_INTEGER		: int		= 2;
		private static const FLAG_FLOAT			: int		= 3;
		private static const FLAG_STRING		: int		= 4;
		private static const FLAG_UTF_STRING	: int		= 5;
		private static const FLAG_BYTES			: int		= 6;
		private static const FLAG_BOOLEAN		: int		= 7;
		
		private static const ENCODERS		: Array		= [encodeObject,
														   encodeArray,
														   encodeInteger,
														   encodeFloat,
														   encodeString,
														   encodeUTFString,
														   encodeBytes,
														   encodeBoolean];
		
		private static const DECODERS		: Array		= [decodeObject,
														   decodeArray,
														   decodeInteger,
														   decodeFloat,
														   decodeString,
														   decodeUTFString,
														   decodeBytes,
														   decodeBoolean];
		
		private static function getTypeFlag(source : *) : int
		{
			if (source is int)
				return FLAG_INTEGER;
			if (source is Number)
				return FLAG_FLOAT;
			if (source is String)
				return FLAG_UTF_STRING;
			if (source is Array)
				return FLAG_ARRAY;
			if (source is ByteArray)
				return FLAG_BYTES;
			if (source is Boolean)
				return FLAG_BOOLEAN;
			
			return FLAG_OBJECT;
		}
		
		public static function encode(...sources) : ByteArray
		{
			var data 	: ByteArray = new ByteArray();
			
			for each (var source : * in sources)
				encodeRecursive(source, data);
			
			data.position = 0;
			
			return data;
		}
		
		public static function decode(source : ByteArray) : Array
		{
			var result : Array = new Array();
			
			while (source.bytesAvailable)
				result.push(decodeRecursive(source));
			
			return result;
		}
		
		public static function encodeRecursive(source : *, target : ByteArray) : void
		{
			var flag : int = getTypeFlag(source);
			
			target.writeByte(flag);
			ENCODERS[flag].call(null, source, target);
		}
		
		public static function decodeRecursive(source : ByteArray) : *
		{
			var flag : int = source.readByte();
			
			return DECODERS[flag].call(null, source);
		}
		
		private static function encodeObject(source : Object, target : ByteArray) : void
		{
			var start	: int = target.position;
			var length 	: int = 0;
			
			target.position += 2;
			
			for (var propertyName : String in source)
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
	
		private static function decodeObject(source : ByteArray) : Object
		{
			var object 	: Object 	= new Object();
			var length	: int		= source.readShort();
			
			for (; length > 0; --length)
				object[decodeString(source)] = decodeRecursive(source);
			
			return object;
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
			target.writeMultiByte(source, "iso-8859-1");
			target.writeByte(0);
		}
		
		private static function decodeString(source : ByteArray) : String
		{
			var byte : int = source.readByte();
			var str : String = "";
			
			while (byte != 0)
			{
				str += String.fromCharCode(byte);
				byte = source.readByte();
			}
			
			return str;
		}
		
		private static function encodeUTFString(source : String, target : ByteArray) : void
		{
			target.writeUTF(source);
		}
		
		private static function decodeUTFString(source : ByteArray) : String
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
	}
}