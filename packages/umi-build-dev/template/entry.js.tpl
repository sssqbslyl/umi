{{{ polyfillImports }}}
{{#globalVariables}}
import history from './history';
{{/globalVariables}}
{{{ importsAhead }}}
import React from 'react';
import ReactDOM from 'react-dom';
import findRoute, { getUrlQuery } from '{{{ findRoutePath }}}';
{{{ imports }}}

// runtime plugins
const plugins = require('umi/_runtimePlugin');
{{#globalVariables}}
window.g_plugins = plugins;
{{/globalVariables}}
plugins.init({
  validKeys: [{{#validKeys}}'{{{ . }}}',{{/validKeys}}],
});
{{#plugins}}
plugins.use(require('{{{ . }}}'));
{{/plugins}}

{{{ codeAhead }}}

// render
let clientRender = async () => {
  {{{ render }}}
};
const render = plugins.compose('render', { initialValue: clientRender });

const moduleBeforeRendererPromises = [];
// client render
if (__IS_BROWSER) {
  {{# moduleBeforeRenderer }}
  if (typeof {{ specifier }} === 'function') {
    const promiseOf{{ specifier }} = {{ specifier }}();
    if (promiseOf{{ specifier }} && promiseOf{{ specifier }}.then) {
      moduleBeforeRendererPromises.push(promiseOf{{ specifier }});
    }
  }
  {{/ moduleBeforeRenderer }}

  Promise.all(moduleBeforeRendererPromises).then(() => {
    render();
  }).catch((err) => {
    window.console && window.console.error(err);
  });
}

// export server render
let serverRender, ReactDOMServer;
if (!__IS_BROWSER) {
  const { matchRoutes } = require('react-router-config');
  const { StaticRouter } = require('react-router')
  const { parsePath } = require('history');
  // don't remove, use stringify html map
  const stringify = require('serialize-javascript');
  const router = require('./router');

  /**
   * 1. Load dynamicImport Component
   * 2. Get Component initialProps function data
   * return Component props
   * @param pathname
   * @param props
   */
  const getInitialProps = async (pathname, props) => {
    const { routes } = router;
    const matchedComponents = matchRoutes(routes, pathname).map(({ route }) => !route.component.preload
      // 同步
      ? route.component
      // 异步，支持 dynamicImport
      : route.component.preload().then(component => component.default));
    const loadedComponents = await Promise.all(matchedComponents);

    // get Store
    const initialProps = plugins.apply('modifyInitialProps', {
      initialValue: {},
    });
    // support getInitialProps
    const promises = loadedComponents.map(component => {
      if (component && component.getInitialProps) {
        return component.getInitialProps({
          isServer: true,
          ...props,
          ...initialProps,
        });
      }
      return Promise.resolve(null);
    });

    return Promise.all(promises);
  }

  serverRender = async (ctx = {}) => {
    // ctx.req.url may be `/bar?locale=en-US`
    const [pathname] = (ctx.req.url || '').split('?');
    // global
    global.req = {
      url: ctx.req.url,
    }
    const location = parsePath(ctx.req.url);
    const activeRoute = findRoute(router.routes, pathname) || {};
    // omit component
    const { component, ...restRoute } = activeRoute;
    const context = {};
    const dataArr = await getInitialProps(pathname, {
        route: restRoute,
        // only exist in server
        req: ctx.req || {},
        res: ctx.res || {},
        context,
        location,
    });

    // 当前路由（不包含 Layout）的 getInitialProps 有返回值
    // Page 没有值时，return dva model
    dataArr[dataArr.length - 1] = plugins.apply('initialProps', {
      initialValue: dataArr[dataArr.length - 1],
    });

    // reduce all match component getInitialProps
    // in the same object key
    // page data key will override layout key
    const props = Array.isArray(dataArr) ? dataArr.reduce((acc, curr) => ({
      ...acc,
      ...curr,
    }), {}) : {};

    const App = React.createElement(StaticRouter, {
      location: ctx.req.url,
      context,
    }, React.createElement(router.default, props));

    // render rootContainer for htmlTemplateMap
    const rootContainer = plugins.apply('rootContainer', {
      initialValue: App,
    });
    const htmlTemplateMap = {
      {{{ htmlTemplateMap }}}
    };
    const matchPath = activeRoute.path;
    return {
      htmlElement: matchPath ? htmlTemplateMap[matchPath] : '',
      rootContainer,
      matchPath,
      g_initialData: props,
    };
  }
  // using project react-dom version
  // https://github.com/facebook/react/issues/13991
  ReactDOMServer = require('react-dom/server');
}

export { ReactDOMServer };
export default __IS_BROWSER ? null : serverRender;

{{{ code }}}

// hot module replacement
if (__IS_BROWSER && module.hot) {
  module.hot.accept('./router', () => {
    clientRender();
  });
}
