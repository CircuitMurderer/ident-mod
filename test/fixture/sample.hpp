#pragma once

#include <stddef.h>

namespace project {

struct Request {};
struct String {};
using Name = char*;

inline int inlineHelper() {
    return 1;
}

constexpr int constexprValue() {
    return 2;
}

template <typename T>
inline T inlineTemplate(T value) {
    return value;
}

template <typename T>
constexpr T constexprTemplate(T value) {
    return value;
}

template <typename T>
T ordinaryTemplate(T value) {
    return value;
}

template <typename T>
class Holder {
public:
    T inlineClassMember(T value) {
        return value;
    }
};

class Processor {
public:
    int GetSize() const;
    static bool IsReady();

    int inlineMember() const {
        return numberOfSlice;
    }

    static inline int staticInlineMember() {
        return 3;
    }

    template <typename T>
    T inlineMemberTemplate(T value) {
        return value;
    }

private:
    int numberOfSlice;
    String keywordName;
    Request currentRequest;
    char* name;
    char displayName[32];
    const char* m_psTitle;
    Name aliasName;
    static double AverageValue;
};

int ComputeValue();
int calculateTotal();

} // namespace project
