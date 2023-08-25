const path = require("path");
const fs = require("fs");
const SolidityParser = require("@solidity-parser/parser");

let remappings;
try {
  remappings = fs.readFileSync(process.cwd() + "/remappings.txt", "utf-8");
  remappings = remappings.split("\n").map((a) => {
    let split = a.split("=");
    return {
      in: split[0],
      out: split[1],
    };
  });
} catch (e) {}

function getGetterParams(getter) {
  return getter.typeName.type === "Mapping"
    ? getter.typeName.valueType.type === "ArrayTypeName"
      ? `${getter.typeName.keyType.name} memory, uint256`
      : `${getter.typeName.keyType.name} memory`
    : getter.typeName.type === "ArrayTypeName"
    ? `uint256`
    : "";
}

const licenseInfo = `// SPDX-License-Identifier: GPL-3.0-only`;

module.exports = function generateInterface(src, options = {}) {
  const ast = SolidityParser.parse(src, { range: true });

  const pragma = ast.children.find(
    (statement) => statement.type === "PragmaDirective"
  );
  const pragmaSrc = pragma
    ? src.slice(pragma.range[0], pragma.range[1] + 1) + "\n\n"
    : "";

  const contract = ast.children.find(
    (statement) => statement.type === "ContractDefinition"
  );

  if (!contract) {
    const fileStructs = ast.children.filter(
      (s) => s.type === "StructDefinition"
    );

    const structs = [...fileStructs].map((s) => {
      return {
        name: s.name,
        path: options.path,
        src: src.slice(s.range[0], s.range[1] + 1),
      };
    });
    options.allStructs.push(...structs);
    return;
  }

  const supers = contract.baseContracts
    .map((supercontract) => supercontract.baseName.namePath)
    .reduce((o, key) => {
      o[key] = 1;
      return o;
    }, {});

  const importStubs = ast.children
    .filter((statement) => statement.type === "ImportDirective")
    .map((statement) => statement.path)
    .filter((filepath) => {
      let contractName = path.basename(filepath, ".sol");
      return contractName in supers;
    })
    // .filter((filepath) => {
    //   let contractName = path.basename(filepath, ".sol");
    //   return !(
    //     contractName.includes("Interface") || contractName.startsWith("I")
    //   );
    // })
    .map((importfile) => {
      // console.log("importfile: ", importfile);
      // console.log("path: ", options.path);

      let remapping = false;
      for (let i = 0; i < remappings.length; i++) {
        let r = remappings[i];
        if (importfile.startsWith(r.in)) {
          importfile = importfile.replace(r.in, r.out);
          remapping = true;
        }
      }
      let absPath = remapping
        ? importfile
        : path.join(path.dirname(options.path), importfile);
      // console.log("abs path: ", absPath);
      let file = fs.readFileSync(path.join(process.cwd(), absPath), "utf-8");

      // generate the interface of the inherited contract
      return {
        path: absPath,
        stubs: generateInterface(file, {
          ...options,
          inherited: true,
          path: absPath,
        }),
      };
    })
    .filter((a) => a.stubs);

  const enumNames = contract.subNodes
    ? contract.subNodes
        .filter((s) => s.type === "EnumDefinition")
        .map((en) => en.name)
    : [];
  const enumRegexp = new RegExp(enumNames.join("|"), "g");
  const replaceEnums = (str) =>
    enumNames.length ? str.replace(enumRegexp, "uint") : str;

  /** handle structs in file/contract
   *
   *  struct Custom {
   *    address a;
   *  }
   *  contract A {
   *    struct Custom2 {
   *      address b;
   *    }
   *  }
   */
  const fileStructs = ast.children.filter((s) => s.type === "StructDefinition");

  const contractStructs = contract.subNodes.filter(
    (s) => s.type === "StructDefinition"
  );

  const contractEnums = contract.subNodes.filter(
    (s) => s.type === "EnumDefinition"
  );
  const structs = [...fileStructs, ...contractStructs, ...contractEnums].map(
    (s) => {
      return {
        name: s.name,
        path: options.path,
        src: replaceEnums(src.slice(s.range[0], s.range[1] + 1)),
      };
    }
  );
  options.allStructs.push(...structs);
  const usedStructs = new Set();

  let functions = contract.subNodes
    ? contract.subNodes
        .filter(
          (s) =>
            s.type == "FunctionDefinition" &&
            (s.visibility == "public" || s.visibility == "external")
        )
        // filter out functions already imported
        // like `function setUp() public virtual override`
        .filter((f) => {
          for (let i of importStubs.map((a) => a.stubs)) {
            if (i.includes(`function ${f.name}(`)) {
              return false;
            }
          }
          return true;
        })
    : [];

  const functionStubs = functions.map((f) => {
    let fName = f.isReceiveEther
      ? "receive"
      : f.isFallback
      ? "fallback"
      : `function ${f.name}`;

    // const nameAndParams =
    // f.parameters.length > 0
    //   ? replaceEnums(
    //       src.slice(
    //         f.range[0],
    //         f.parameters[f.parameters.length - 1].range[1] + 1
    //       ) + ")"
    //     )
    //   : `${fName}()`;

    const nameAndParams =
      f.parameters.length > 0
        ? src.slice(f.range[0], f.parameters[0].range[0]) +
          f.parameters
            .map((param) => {
              param = replaceEnums(
                src.slice(param.range[0], param.range[1] + 1).trim()
              );

              let bareParam = param.split(" ")[0];
              if (bareParam.endsWith("[]")) {
                bareParam = bareParam.slice(0, -2);
              }

              let structNode = options.allStructs.find(
                (_s) => _s.name === bareParam
              );
              if (structNode) {
                options.addedImports.add(structNode.path);
                return `${
                  path.basename(structNode.path).split(".")[0]
                }.${param}`;
              }

              return param;
            })
            .join(", ") +
          ")"
        : `${fName}()`;

    // function get(Custom memory m) external returns (Custom memory _m);
    f.parameters.forEach((p) => {
      if (p.typeName.namePath) {
        usedStructs.add(p.typeName.namePath);
      } else if (p.typeName.baseTypeName && p.typeName.baseTypeName.namePath) {
        usedStructs.add(p.typeName.baseTypeName.namePath);
      }
    });

    // always set stateVisibilility to external
    let extras = " external";
    if (f.stateMutability) {
      extras += " " + f.stateMutability;
    }
    if (f.returnParameters) {
      // function get(Custom memory m) external returns (Custom memory _m);
      f.returnParameters.forEach((p) => {
        if (p.typeName.namePath) {
          usedStructs.add(p.typeName.namePath);
        } else if (
          p.typeName.baseTypeName &&
          p.typeName.baseTypeName.namePath
        ) {
          usedStructs.add(p.typeName.baseTypeName.namePath);
        }
      });

      extras +=
        " returns (" +
        f.returnParameters
          .map((returnParam) => {
            let param = replaceEnums(
              src.slice(returnParam.range[0], returnParam.range[1] + 1).trim()
            );

            let bareParam = param.split(" ")[0];
            if (bareParam.endsWith("[]")) {
              bareParam = bareParam.slice(0, -2);
            }

            let structNode = options.allStructs.find(
              (_s) => _s.name === bareParam
            );
            if (structNode) {
              options.addedImports.add(structNode.path);
              return `${path.basename(structNode.path).split(".")[0]}.${param}`;
            }

            return param;
          })
          .join(", ") +
        ")";
    }

    return `  ${nameAndParams}${extras};`;
  });

  // only public variables
  const getters = contract.subNodes
    ? contract.subNodes
        .filter(
          (s) =>
            s.variables &&
            s.variables[0] &&
            s.variables[0].type === "VariableDeclaration" &&
            s.variables[0].visibility === "public"
        )
        .map((a) => a.variables[0])
    : [];

  /** handle built-in types, user defined types, arrays, mappings, strings
   *  address public a;
   *  Custom public b;
   *  address[] public c;
   *  Custom[] public d;
   *  mapping(string => address) public e;
   *  mapping(string => address[]) public f;
   *  mapping(string => Custom) public g;
   *  mapping(string => Custom[]) public h;
   *  string public i;
   *  string[] public j;
   *  mapping(string => string) public k;
   *  mapping(string => string[]) public l;
   *
   *  function a() external view returns (address);
   *  function b() external view returns (Custom memory);
   *  function c(uint256) external view returns (address);
   *  function d(uint256) external view returns (Custom memory);
   *  function e(string memory) external view returns (address);
   *  function f(string memory, uint256) external view returns (address);
   *  function g(string memory) external view returns (Custom memory);
   *  function h(string memory, uint256) external view returns (Custom memory);
   *  function i() external view returns (string memory);
   *  function j(uint256) external view returns (string memory);
   *  function k(string memory) external view returns (string memory);
   *  function l(string memory, uint256) external view returns (string memory);
   */
  const getterStubs = getters
    .filter((g) => g.name !== "HEAD") // @dev hack
    .map((getter) => {
      let returnType = getter.typeName.name;

      if (getter.typeName.namePath) {
        usedStructs.add(getter.typeName.namePath);
        returnType = `${getter.typeName.namePath} memory`;
      } else if (getter.typeName.baseTypeName) {
        if (getter.typeName.baseTypeName.name) {
          returnType = getter.typeName.baseTypeName.name;
        } else if (getter.typeName.baseTypeName.namePath) {
          usedStructs.add(getter.typeName.baseTypeName.namePath);
          returnType = `${getter.typeName.baseTypeName.namePath} memory`;
        }
      } else if (getter.typeName.type === "Mapping") {
        if (getter.typeName.valueType.namePath) {
          usedStructs.add(getter.typeName.valueType.namePath);
          returnType = `${getter.typeName.valueType.namePath} memory`;
        } else if (getter.typeName.valueType) {
          if (getter.typeName.valueType.name) {
            returnType = getter.typeName.valueType.name;
          } else if (getter.typeName.valueType.baseTypeName.name) {
            returnType = getter.typeName.valueType.baseTypeName.name;
          } else if (getter.typeName.valueType.baseTypeName.namePath) {
            usedStructs.add(getter.typeName.valueType.baseTypeName.namePath);
            returnType = `${getter.typeName.valueType.baseTypeName.namePath} memory`;
          }
        }
      }

      if (returnType.includes("memory")) {
        let bareReturn = returnType.split(" ")[0];
        if (bareReturn.endsWith("[]")) {
          bareReturn = bareReturn.slice(0, -2);
        }

        let structNode = options.allStructs.find(
          (_s) => _s.name === bareReturn
        );
        if (!structNode) {
          // incorrect: thought you use (ICustom memory)
          // if (!returnType.startsWith("I")) {
          //   // no struct, use interface
          //   returnType = `I${returnType}`;
          //   addedImports.add(returnType.split(" ")[0]);
          // }

          // for a custom type
          // instead use returns (address)
          returnType = "address";
        } else {
          options.addedImports.add(structNode.path);
          returnType = `${
            path.basename(structNode.path).split(".")[0]
          }.${returnType}`;
        }
      }

      if (returnType === "string") {
        returnType += ` memory`;
      }

      return `  function ${getter.name}(${getGetterParams(
        getter
      )}) external view returns (${returnType});`;
    });

  let structsArr = Array.from(usedStructs);

  // let structStubs =
  //   structsArr.length > 0
  //     ? [
  //         `  // Structs`,
  //         ...structsArr.map((s) => {
  //           let structNode = options.allStructs.find((_s) => _s.name === s);
  //           if (structNode && !options.addedStructs.has(structNode)) {
  //             options.addedStructs.add(structNode);
  //             return structNode.src;
  //           } else {
  //             return "";
  //           }
  //         }),
  //       ]
  //     : [];

  const structImports = ast.children
    .filter((statement) => statement.type === "ImportDirective")
    .filter((statement) => {
      // @dev assumed names were the same as the file
      // let contractName = path.basename(statement.path, ".sol");
      // return structsArr.find((s) => s.startsWith(contractName));

      // check usage of import names
      if (statement.symbolAliases) {
        return structsArr.find((s) => {
          // "STypes.Order"
          if (s.includes(".")) {
            return s.split(".")[0] == statement.symbolAliases[0][0];
          } else {
            // O
            return s == statement.symbolAliases[0][0];
          }
        });
      }
      return true;
    })
    .map((statement) => {
      let contractName = path.basename(statement.path, ".sol");

      return {
        path: statement.path,
        name: contractName,
        symbolAliases: statement?.symbolAliases?.map((a) => a[0]) || [],
      };
    });

  if (
    contract.kind === "interface" ||
    contract.kind === "library"
    // contract.name.includes("Interface") ||
    // contract.name.startsWith("I") ||
    // contract.kind === "abstract"
  ) {
    return importStubs.map((s) => s.stubs).join("\n");
  }

  // console.log(options.allStructs.map((a) => a.name));
  // console.log(functionStubs);

  let stubs = []
    .concat(
      importStubs.length > 0 ? importStubs.map((s) => s.stubs) : [],
      // structStubs,
      getterStubs.length > 0
        ? [
            `  // public getters from ${options.path}`,
            ...getterStubs.map((a) => `${a}`),
          ]
        : [],
      functionStubs.length > 0
        ? [`\n  // functions from ${options.path}`, ...functionStubs]
        : []
    )
    .join("\n")
    .replace(/\n{2,}/gm, "\n\n");

  // if facet
  if (contract.name.endsWith("Facet")) {
    options.facets.push({
      structImports,
      stubs,
    });
  }

  if (contract.name == "Diamond") {
    options.facets.forEach((f) => {
      stubs += f.stubs;
      Array.from(f.structImports).forEach((i) => {
        options.addedImports.add(i.path);
      });
    });
  }

  let structImportStr = "";
  if (structImports.length > 0) {
    structImports.forEach((i) => {
      // structImportStr += `import {${i.name}} from "${i.path}";\n`;
      // might have more than one import
      structImportStr += `import {${i.symbolAliases.join(",")}} from "${
        i.path
      }";\n`;
    });
  }

  let imports =
    Array.from(options.addedImports)
      .map((i) => {
        return `import "${i}";`;
      })
      .join("\n") +
    "\n" +
    structImportStr +
    "\n";

  //TODO: remove and fix this (isol doesn't like structs in function returns (works with params and function bodies))
  if (contract.name == "Diamond") {
    imports =
      `import {IDiamondLoupe} from "contracts/interfaces/IDiamondLoupe.sol";\n` +
      `import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";\n` +
      imports;
  }

  if (options.inherited) {
    return stubs;
  } else if (
    contract.kind === "interface" ||
    contract.name.includes("Interface") ||
    contract.name.startsWith("I") ||
    // contract.kind === "abstract" ||
    contract.kind === "library"
  ) {
    return "";
  } else if (stubs != "") {
    return `${licenseInfo}\n${pragmaSrc}${imports}interface I${contract.name} {
${stubs}
}`;
  }
};
