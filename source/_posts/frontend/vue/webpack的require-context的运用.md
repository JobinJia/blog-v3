---
title: webpack的require.context的运用
date: 2020-04-09 14:02:14
tags:
categories:
 - 前端
 - vue
---

# 构建项目中合理利用require.context进行优化

## 自定义组件批量全局加载
也是常见的可以使用该方法的地方

```
import Vue from 'vue'

// arg1: 自定义组件所在的路径 arg2: 是否遍历路径下中的子文件夹, arg3: 匹配的正则
const requireComponents = require.context('../components/AppBase', true, /\.vue|js/)
requireComponents.keys().forEach(fileName => {
  const reqCom = requireComponents(fileName)
  const reqComName = reqCom.default.name // 使用组件中 name属性做为全局的组件名进行注册
  Vue.component(reqComName, reqCom.default || reqCom)
})  
```

## vuex中当store分module之后的加载

一般情况下结构是
```
|-- store
  |--modules
     - app.js
     - user.js
     - xxx.js
  |--index.js
```
那么在index.js中导入是这样
```
import Vue from 'vue'
import Vuex from 'vuex'
import app from './modules/app'
import user from './modules/user'
Vue.use(Vuex)
export default new Vuex.Store {
   modules: {
    app,
    user
   }
}
```
如果使用require.context
```
import Vue from 'vue'
import Vuex from 'vuex'

Vue.use(Vuex)

const requireStore = require.context('./modules/', false, /[a-z]\w+\.(js)$/)
/*
 store = {
    app,
    user,
    xxx
 }
*/
const modules = requireStore.keys().reduce((p, n) => {
  // 获取store的名字
  const name = n.replace(/\.\//, '').replace(/\.js/, '')
  const store = {}
  store[name] = requireStore(n).default
  return { ...p, ...store }
}, {})

export default new Vuex.Store({
  modules
})

```
这种引入的方式，推荐开启Vuex的命名空间(namespace: true),另外需要注意的是

1. 强烈建议使用mapSates, mapActions这种方使来调用。因为开了命名空间。
所以可以指定加载某个store.
eg:
```
import { createNamespacedHelpers } from 'vuex'
const { mapState, mapMutations, mapActions } = createNamespacedHelpers('app') // 参数为require.context加载时候的name
```
2. 还有一个点需要注意的是在创建vue实例是，即在main.js中new Vue的时候要加载一个启动项，而这个启动项需要调用到store的时候
是需要处理下的。
代码

main.js
```
import bootstrap from './utils/bootstrap'
new Vue({
  router,
  store,
  created: bootstrap,
  render: h => h(App)
}).$mount('#app')

```
bootstrap.js

比如我在此时初始化路由
```
import { createNamespacedHelpers } from 'vuex'
const { mapActions } = createNamespacedHelpers('app')

export default function initApp () {
  const { setMenusList } = mapActions(['setMenusList'])
  setMenusList.call(this, []).then(r => {}).catch(e => {})
}
```
在这里面store中app.js里的内容
```
import routes from '../../router/routes'
import { APP_BASE_ROUTE } from '../../config'
import { getMenuList } from '../../utils/utils'
import Vue from 'vue'

export default {
  namespaced: true,
  state: {
    currentMenu: APP_BASE_ROUTE, // 当前顶级菜单
    subMenuList: [],
    collapsed: false,
    menuList: [],
    dataMap: null
  },
  getters: {
    dataMap: state => {
      return state.dataMap ? state.dataMap : Vue.ls.get('DATA_MAP')
    }
  },
  mutations: {
    SET_DATA_MAP: (state, map) => {
      state.dataMap = map
      Vue.ls.set('DATA_MAP', map)
    },
    TOGGLE_COLLAPSED: state => {
      state.collapsed = !state.collapsed
    },
    SET_MENU_LIST: (state, menuList) => {
      state.menuList = menuList
    },
    SET_SUB_MENUS: (state, menu) => {
      const { menuList } = state
      const subMenu = menuList.find(it => it.name === menu.name)
      const { children } = subMenu
      state.subMenuList = children
    },
    SET_APP_BREADCRUMB: (state, menu) => {
      // console.log(menu)
    }
  },
  actions: {
    setMenusList: ({ state, commit }, backendMenuList) => {
      commit('SET_MENU_LIST', getMenuList(routes, backendMenuList))
      commit('SET_SUB_MENUS', { name: state.currentMenu })
      commit('SET_APP_BREADCRUMB', { name: state.currentMenu })
    },
    async loadSystemMaps ({ commit }) {
      const response = await Vue.$http.app.getLanguage()
      const { data } = response
      commit('SET_DATA_MAP', data)
    }
  }
}

```
## api请求模块
1. 在项目较大时，可能会有多个模块有多个请求，同理也可以使用require.context来处理

http/modules/test.js
```
import axios from 'axios'
export const getTableList = data => {
  return axios.request({
    url: '/xxx/xx',
    data,
    method: 'POST'
  })
}
```

http/index.js
```
import Vue from 'vue'
const requireHttpModule = require.context('./modules', false, /\.js/)

const modules = requireHttpModule.keys().reduce((p, n) => {
  const name = n.replace(/\.\//, '').replace(/\.js/, '')
  const store = {}
  store[name] = requireHttpModule(n)
  return { ...p, ...store }
}, {})
export default modules

```
src/main.js

这里可以抽成Vue Plugin的插件的形式。这里简单处理，直接绑定在原型上了
```
import Vue from 'vue'
import http from './http'

Vue.prototype.$http = http
```
那么在调用的时候可以使用
```
methods: {
  async getTableList () {
     // 调用方式就是 this.$http[模块名][api方法名]
     const response = await this.$http.test.getTableList()
     console.log(response)
  }
}
```

---- end
