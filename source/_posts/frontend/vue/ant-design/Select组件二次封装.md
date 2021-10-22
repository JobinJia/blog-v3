---
title: Select组件二次封装
date: 2020-06-22 18:45:10
tags:
categories: 
 - 前端
 - vue
 - ant-design
---

``` 
/**
 * @Date: 2020-05-26 15:31
 * @author jiabinbin
 * @Email 425605679@qq.com
 * @Description:
 */
import S from 'ant-design-vue/es/select'
import { isPromise } from '../../../utils/utils' // 判断是否是promise
import { getDefaultProps } from '../../_utils' // 参见upload组件中的getDefaultProps

const BSelect = {
  name: 'BSelect',
  props: Object.assign({}, S.props, {
    loadOptions: { // a-select-option数组对象
      type: Array | Promise,
      required: true
    },
    optionKey: { // selectOption的key
      type: String,
      default: 'id'
    },
    optionValue: { // selectOption的value
      type: String,
      default: 'value'
    },
    keyValue: { // 有时候需要展示值为 00-完成 01-未完成 02-待确定。开启之后 option的value和label同时展示
      type: Boolean,
      default: false
    },
    keyValueSplit: { // 开启keyValue之后，keyValue的连接符
      type: String,
      default: '-'
    }
  }),
  model: {
    prop: 'value',
    event: 'change'
  },
  data: () => ({
    optionList: []
  }),
  created () {
    this.loadData()
  },
  watch: {
    loadOptions: {
      handler (c, n) {
        this.loadData()
      }
    },
    immediate: true
  },
  methods: {
    loadData () {
      if (isPromise(this.loadOptions)) {
        this.loadOptions.then(({ data }) => {
          this.optionList = data
        })
      } else {
        this.optionList = this.loadOptions
      }
    },
    renderOptions () {
      const { optionList } = this
      const { optionKey, optionValue, keyValue, keyValueSplit } = this
      return (
        optionList.map(item => {
          const key = item[optionKey]
          const value = item[optionValue]
          const title = keyValue ? `${key} ${keyValueSplit} ${value}` : `${value}`
          return (
            !keyValue ? (
              <a-select-option key={key} title={value} value={key}>{value}</a-select-option>
            ) : (
              <a-select-option key={key} title={title} value={key}>{key} {keyValueSplit} {value}</a-select-option>
            )
          )
        })
      )
    }
  },
  render () {
    // props
    const props = getDefaultProps(S.props, this)
    const options = this.renderOptions()
    return (
      <a-select {...{ props }} {...{ on: this.$listeners }} value={this.model}>
        {options}
      </a-select>
    )
  }
}

export default BSelect

```
