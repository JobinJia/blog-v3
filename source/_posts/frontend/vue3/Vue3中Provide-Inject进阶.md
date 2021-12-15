---
layout: archives
title: Vue3 中 Provide/Inject 深入理解和使用场景
date: 2021-12-15 14:23:20
tags:
categories:
  - 前端
  - vue3
---

在 vue3 文档中，关于 provide 和 inject 的组件，官方有以下的说明

**可以将依赖注入看作是“长距离的 prop”，除了：
父组件不需要知道哪些子组件使用了它 provide 的 property
子组件不需要知道 inject 的 property 来自哪里**

所以一般来说，在composition-api中，我们使用会是

在父组件中注入
```vue
  <script setup lang="ts">
    import { ref, provide } from 'vue'

    const state = ref<Record<string, any>>({})

    provide('provideState', state)
  </script>
  <template>
    <div>
      <Child1 />
      <Child2 />
    </div>
  </template>
```
在父组件中注入
```vue
  <script setup lang="ts">
    // Child1.Vue
    import { ref, inject } from 'vue'
    const provideState = inject('provideState')

    // to use provideState
  </script>
  <template>
    <div>
      <Child1 />
      <Child2 />
    </div>
  </template>
```

以上的使用是常规的做法，这样的话会有一个有选择的问题就是： 如果注入的state 是响应试的，那么在子组件中，就可以改变这个provide注入的值，
如果子组件都引用的情况下，都能改变，后期的代码就会不好维护。但如果state 不是响应式的，即provide(state)中state是一个普通对象时，那么
在父组件中如果当state改变时，子组件保证同步，从而丢失使用provide的意义。所以我们怎么选？

答案很明显，因为在ts中，我们可以使用`readonly`修饰符来让注入的对象是响应式的，但是是只读的。这样子组件能及时响应到数据，而不能修改这个数据。

```ts
// in provide
const state = ref({
  a: 1,
  b: 2
})
provide(key, readonly(state))
```
```ts
// in inject
const state = inject(key)
// state 此时是只读响应
console.log(state.value.a, state.value.b)
```

到了这一步，不可避免的就是在子组件中，使用这些数据，一定会涉及到这个数据的更应，不然，就没有意义了。所以，官方文档上提供了一种方式，
就是在注入的时候，同时提供一个注入的函数，用来改变state的值。即:
```ts
  // 父组件
  interface State { 
    a: number
    b: number
  }
  const state = ref<State>({
    a:1,
    b:2,
  })

  function setState (o: State) {
    state.value = {
      ...state.value,
      ...o
    }
  } 

  provide('provideState', readonly(state))
  provide('setState', readonly(setState))

```

```vue
  // 子组件
  <script setup lang="ts">
    const provideState = inject('provideState')
    const setState = inject('setState')

    function click() {
      setState({ 
        a: 2
      })
    }
  </script>
  <template>
    <button @click="click">Change</button>
  </template>
```

但是，如果只是这样，那么如果我们在不同组件中，都这么写，随着key的变多，就会非常不好维护。所以为了方便更好的使用(套娃)
我们需要** 多次 **封装一下 provide 及 inject

> 第一次封装，提供公有的 注入 和 使用的方法，并返回注入的对象，及改变对象的方法

```typescript
  // useContext.ts
  import type { Ref } from 'vue'
  import { isRef, provide, ref } from 'vue'
  type MaybeRef<T> = Ref<T> | T

  export type SetProvideState<T> = (payload: Partial<MaybeRef<T>>) => void

  export interface CreateContextReturn<T> {
    provideState: Ref<UnwrapRef<T>>
    setProvideState: SetProvideState<T>
  }

  //  createContext
  export function createContext<T>(
    key: Injection<T>,
    payload: MaybeRef<T>,
    setStateInjectKey?: InjectionKey<SetProvideState<T>>
  ): CreateContextReturn<T> {
    function get<T, K extends keyof T>(obj: MaybeRef<T>, key?: K): T | T[K] {
      const data = isRef(obj) ? obj.value : obj
      return key ? data[key] : data
    }
    
    // computed接收
    const defState = computed(() => {
      return get(payload)
    })

    // 定义要provide的变量
    const provideState = ref<T>({ ...get(defState) })

    provide<Ref<UnwrapRef<T>>>(key, provideState)
    
    function setProvideState<T>(payload: Partial<MaybeRef<T>>): void {
      provideState.value = {
        ...provideState.value,
        ...payload
      }
    }

    // 如果上层调用传递了 更新函数的key, 则注入，否则不注入
    if (setStateInjectKey) {
      provide<SetProvideState<T>>(setStateInjectKey, setProvideState)
    }

    return { provideState, setProvideState }
  }

  // useContext
  export function useContext<T>(key: Injection<T>): T {
    return inject<T>(key)
  }

```


以上这样包了一层后，那么我们上层调用就会变得简单了

```ts
  // 父组件中

  //  如果是响应式的state
  const state = ref({ a: 1, b: 2 })
  createContext('provideState', state)
  // 那么在state变了之后，子组件还是会变


  // 非向应式的state
  const state1 = { a: 2, b: 3 }
  // 这样的数据，在state1变化后，注入的值并不会改变，要改变值怎么办呢？
  // 还记得createContext返回的内容吗？
  const { provideState, setProvideState } = createContext('provideState', state1)
  // 这样返回的provideState,父组件也可以使用.比如
  const a = computed(() => provideState.value.a)
  // 而改变值的时候，则是  
  function updateValue (val) {
    setProvideState({
      a: val
    })
  }
```


```ts
  // 子组件中
  const provideState = useContext('provideState')
```

到了这里，还没有完，因为这就涉及到在不同组件中写很多provide~, 所以我们需要针对不同的组件，再依赖于 createContext, useContext再包一层。
而且上面我们在createContext中，有三个参数，我需要针对第三个参数，对子组件提供出修改provideState的方法

比如 现在有一个layout组件，要注入一些主题，之类的那么我们可以建一个useLayoutContext.ts文件，
```
import { MaybeRef } from '@vueuse/core'
import { createContext, UpdateProvideState, useContext } from '@/composables/useContext'
import { InjectionKey, Ref } from 'vue'

export interface AppTheme {
  inverted: boolean
}

export interface LayoutContextData {
  collapsed: MaybeRef<boolean>
  isMobile: MaybeRef<boolean>
  theme: AppTheme
}

const stateKey: InjectionKey<LayoutContextData> = Symbol()
const updateStateKey: InjectionKey<UpdateProvideState<LayoutContextData>> = Symbol()

export function createLayoutContextData(payload: MaybeRef<LayoutContextData>) {
  return createContext(stateKey, payload, updateStateKey)
}

export function useLayoutContextData(): {
  provideState: Ref<LayoutContextData>
} {
  const provideState = useContext<Ref<LayoutContextData>>(stateKey)
  const setProvideState = useContext<UpdateProvideState<LayoutContextData>>(updateStateKey)
  return {
    provideState,
    provideState
  }
}
```

那么顶层组件 创建 provide 就可以

``` ts
  const provideState = ref({})
  const { provideState: state, updProvideState } = createLayoutContextData(provideState)

```

而子组件中

```ts
  const { provideState, updateState } = useLayoutContextData()
  // 消费 provideState 和updateState
```

而在其它的组件里，同理。这样方便管理injectKey以及注入的 状态数据



### 其它

#### 实现一个全局状态

  只要把readonly去掉，让其在子组件中可以修改，就是全局状态管理 ：） 是不是so easy!

