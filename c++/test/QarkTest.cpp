//
//  Created by Warren Seine on Oct 1, 2011.
//  Copyright (c) 2011 Aerys. All rights reserved.
//

#include <aerys/qark/Qark.hpp>
#include <iostream>

using namespace aerys::qark;

template <typename T>
bool compare(const Qark::Object& a, const Qark::Object& b)
{
  return boost::any_cast<T>(a) == boost::any_cast<T>(b);
}

int main()
{
  Qark::Object object = 42;

  Qark::ByteArray data = Qark::encode(object);

  Qark::Object result = Qark::decode(data);

  std::cout << compare<int>(object, result) << std::endl;
}
