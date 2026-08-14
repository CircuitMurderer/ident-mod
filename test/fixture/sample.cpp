#include "sample.hpp"

namespace project {

template <>
int inlineTemplate<int>(int value) {
    return value;
}

const int TIME_ESCAPE = 30;
int NON_CONST_VALUE = 40;
const int* POINTER_TO_CONST = nullptr;
int* const CONST_POINTER = nullptr;

double Processor::AverageValue = 1.0;

int Processor::GetSize() const {
    return numberOfSlice;
}

bool Processor::IsReady() {
    return AverageValue > 0;
}

int ComputeValue() {
    int result = 42;
    return result;
}

int calculateTotal() {
    char* funcName = nullptr;
    static char* cachedFuncName = nullptr;
    return funcName == cachedFuncName ? 1 : 0;
}

int useTemplates(Processor& processor) {
    Holder<int> TemplateHolder;
    return (&inlineHelper)() + inlineTemplate<int>(1) + constexprTemplate<int>(2) +
        ordinaryTemplate(3) + (processor.*(&Processor::inlineMember))() +
        Processor::staticInlineMember() + processor.inlineMemberTemplate<int>(4) +
        TemplateHolder.inlineClassMember(5);
}

int SignedConversion(unsigned int value) {
    return value;
}

String defaultKeyword;
char** names;
char** g_ppsAliases;
static char* globalFuncName = nullptr;

} // namespace project
