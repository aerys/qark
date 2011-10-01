//
//  Created by Warren Seine on Oct 1, 2011.
//  Copyright (c) 2011 Aerys. All rights reserved.
//

#pragma once

#include <iostream>
#include <list>
#include <map>
#include <typeinfo>
#include <vector>

#include <boost/any.hpp>
#include <boost/asio/streambuf.hpp>

namespace aerys
{
  namespace qark
  {
    class Qark
    {
    public:
      static const int                  MAGIC                   = 0x3121322b;

      static const int                  FLAG_NONE               = 0;
      static const int                  FLAG_GZIP               = 1;
      static const int                  FLAG_DEFLATE            = 2;

      static const int                  TYPE_CUSTOM             = 0;
      static const int                  TYPE_OBJECT             = 1;
      static const int                  TYPE_ARRAY              = 2;
      static const int                  TYPE_INT                = 3;
      static const int                  TYPE_UINT               = 4;
      static const int                  TYPE_FLOAT              = 5;
      static const int                  TYPE_STRING             = 6;
      static const int                  TYPE_BYTES              = 7;
      static const int                  TYPE_BOOLEAN            = 8;
      static const int                  TYPE_BITMAP_DATA        = 9;

      typedef std::vector<char>         ByteArray;
      typedef boost::any                Object;
      typedef std::string               String;
      typedef std::list<Object>         Array;
      typedef std::map<String, Object>  Map;

      typedef void (*Encoder)(std::ostream&, const Object&);
      typedef void (*Decoder)(std::istream&, Object&);

    public:
      static ByteArray encode(const Object& source)
      {
        boost::asio::streambuf buffer;
        std::ostream stream(&buffer);

        int magic = MAGIC;
        write(stream, magic);
        encodeRecursive(stream, source);

        const char* data = boost::asio::buffer_cast<const char*>(buffer.data());
        std::size_t size = buffer.size();

        return ByteArray(data, data + size);
      }

      static Object decode(const ByteArray& source)
      {
        boost::asio::streambuf buffer;
        std::iostream stream(&buffer);

        stream.write(&*source.begin(), source.size());

        int magic = 0;
        read(stream, magic);

        if (magic != MAGIC)
          return Object();

        Object result;
        decodeRecursive(stream, result);
        return result;
      }

    private:
      static int getType(const Object& source)
      {
        if (source.type() == typeid(int))
          return TYPE_INT;
        if (source.type() == typeid(unsigned int))
          return TYPE_UINT;
        if (source.type() == typeid(float))
          return TYPE_FLOAT;
        if (source.type() == typeid(String))
          return TYPE_STRING;
        if (source.type() == typeid(Array))
          return TYPE_ARRAY;
        if (source.type() == typeid(ByteArray))
          return TYPE_BYTES;
        if (source.type() == typeid(bool))
          return TYPE_BOOLEAN;
        if (source.type() == typeid(Map))
          return TYPE_OBJECT;

        return TYPE_CUSTOM;
      }

      static Encoder getEncoder(char flag)
      {
        static std::map<char, Encoder> encoders;

        if (encoders.empty())
        {
          encoders[TYPE_INT] = &Qark::encodeTrivial<int>;
        }

        return encoders[flag];
      }

      static Decoder getDecoder(char flag)
      {
        static std::map<char, Decoder> decoders;

        if (decoders.empty())
        {
          decoders[TYPE_INT] = &Qark::decodeTrivial<int>;
        }

        return decoders[flag];
      }

      static void encodeRecursive(std::ostream& target, const Object& source)
      {
        char flag = getType(source);
        write(target, flag);

        Encoder f = getEncoder(flag);
        f(target, source);
      }

      static void decodeRecursive(std::istream& source, Object& target)
      {
        char flag = 0;
        read(source, flag);

        Decoder f = getDecoder(flag);
        f(source, target);
      }

      template <typename T>
      static void
      write(std::ostream& stream, const T& value)
      {
        stream.write(reinterpret_cast<const char*>(&value), sizeof (T));
      }

      template <typename T>
      static void
      read(std::istream& stream, T& value)
      {
        stream.read(reinterpret_cast<char*>(&value), sizeof (T));
      }

      template <typename T>
      static void
      encodeTrivial(std::ostream& stream, const Object& value)
      {
        write(stream, boost::any_cast<const T&>(value));
      }

      template <typename T>
      static void
      decodeTrivial(std::istream& stream, Object& value)
      {
        value = T();
        read(stream, boost::any_cast<T&>(value));
      }

      static void
      encodeString(std::ostream& stream, const String& value)
      {
        unsigned short size = value.size();

        write(stream, size);
        stream.write(value.c_str(), size);
      }

      static void
      decodeString(std::istream& stream, String& value)
      {
        // FIXME: Doesn't work with non-ASCI strings.
        unsigned short size = 0;
        read(stream, size);

        char data[size];
        stream.read(data, size);
        value.assign(data, size);
      }
    };
  }
}
