namespace dgl {
namespace kernel {
namespace cuda {

namespace binary {
template <typename DType>
struct Add {
  static __device__ __forceinline__ DType Call(
      const DType *lhs, const DType *rhs, int64_t len_lhs = 1, int64_t len_rhs = 1) {
    return lhs[0] + rhs[0];
  }
  static __device__ __forceinline__ bool UseLhs() {
    return true;
  }
  static __device__ __forceinline__ bool UseRhs() {
    return true;
  }
  static __device__ __forceinline__ bool ReduceDim() {
    return false;
  }
  static __device__ __forceinline__ int64_t ReduceSize(int64_t *feat_shp, int64_t ndim) {
    return 1;
  }
};

template <typename DType>
struct Mul {
  static __device__ __forceinline__ DType Call(
      const DType *lhs, const DType *rhs, int64_t len_lhs = 1, int64_t len_rhs = 1) {
    return lhs[0] * rhs[0];
  }
  static __device__ __forceinline__ bool UseLhs() {
    return true;
  }
  static __device__ __forceinline__ bool UseRhs() {
    return true;
  }
  static __device__ __forceinline__ bool ReduceDim() {
    return false;
  }
  static __device__ __forceinline__ int64_t ReduceSize(int64_t *feat_shp, int64_t ndim) {
    return 1;
  }
};

template <typename DType>
struct CopyU {
  static __device__ __forceinline__ DType Call(
      const DType *lhs, const DType *rhs, int64_t len_lhs = 1, int64_t len_rhs = 1) {
    return lhs[0];
  }
  static __device__ __forceinline__ bool UseLhs() {
    return true;
  }
  static __device__ __forceinline__ bool UseRhs() {
    return false;
  }
  static __device__ __forceinline__ bool ReduceDim() {
    return false;
  }
  static __device__ __forceinline__ int64_t ReduceSize(int64_t *feat_shp, int64_t ndim) {
    return 1;
  }
};

template <typename DType>
struct CopyE {
  static __device__ __forceinline__ DType Call(
      const DType *lhs, const DType *rhs, int64_t len_lhs = 1, int64_t len_rhs = 1) {
    return rhs[0];
  }
  static __device__ __forceinline__ bool UseLhs() {
    return false;
  }
  static __device__ __forceinline__ bool UseRhs() {
    return true;
  }
  static __device__ __forceinline__ bool ReduceDim() {
    return false;
  }
  static __device__ __forceinline__ int64_t ReduceSize(int64_t *feat_shp, int64_t ndim) {
    return 1;
  }
};

template <typename DType>
struct Dot {
  static __device__ __forceinline__ DType Call(
      const DType *lhs, const DType *rhs, int64_t len_lhs = 1, int64_t len_rhs = 1) {
    DType rst = static_cast<DType>(0);
    for (int64_t i = 0; i < max(len_lhs, len_rhs); ++i) {
      rst += lhs[min(i, len_lhs - 1)] * rhs[min(i, len_rhs - 1)];
    }
    return rst;
  }
  static __device__ __forceinline__ bool UseLhs() {
    return true;
  }
  static __device__ __forceinline__ bool UseRhs() {
    return true;
  }
  static __device__ __forceinline__ bool ReduceDim() {
    return true;
  }
  static __device__ __forceinline__ int64_t ReduceSize(int64_t *feat_shp, int64_t ndim) {
    return feat_shp[ndim - 1];
  }
};


}   // end of namespace binary

namespace reduce {
template <typename Idx,
          typename DType,
          bool atomic=false>
struct Sum {
  static constexpr DType zero = 0;
  static __device__ __forceinline__ void Call(
    DType *out_buf, Idx *arg_u_buf, Idx *arg_e_buf,
    DType val, Idx uid, Idx eid) {
    if (!atomic) {
      *out_buf += val;
    } else {
      cuda::AtomicAdd(out_buf, val);
    }
  }
  static __device__ __forceinline__ bool RequireArg() {
    return false;
  }
  static __device__ __forceinline__ void CallArg(Idx fid,
    Idx *arg_u_buf, Idx *arg_e_buf,
    DType val, DType val_ref, Idx uid, Idx eid) {
      // placeholder
    }
};

template <typename Idx,
          typename DType,
          bool atomic=false>
struct Max {
  static constexpr DType zero = std::numeric_limits<DType>::lowest();
  static __device__ __forceinline__ void Call(
    DType *out_buf, Idx *arg_u_buf, Idx *arg_e_buf,
    DType val, Idx uid, Idx eid) {
    if (!atomic) {
      if (*out_buf < val) {
        *out_buf = val;
        *arg_u_buf = uid;
        *arg_e_buf = eid;
      }
    } else {
      cuda::AtomicMax(out_buf, val);
    }
  }
  static __device__ __forceinline__ bool RequireArg() {
    return true;
  }
  static __device__ __forceinline__ void CallArg(Idx fid,
    Idx *arg_u_buf, Idx *arg_e_buf,
    DType val, DType val_ref, Idx uid, Idx eid) {
    if (atomic) {
      if (val == val_ref) {
        if (arg_u_buf)
          arg_u_buf[fid] = uid; // TODO(zihao): select min?
        if (arg_e_buf)
          arg_e_buf[fid] = eid;
      }
    }
  }
};

template <typename Idx,
          typename DType,
          bool atomic=false>
struct Min {
  static constexpr DType zero = std::numeric_limits<DType>::max();
  static __device__ __forceinline__ void Call(
    DType *out_buf, Idx *arg_u_buf, Idx *arg_e_buf,
    DType val, Idx uid, Idx eid) {
    if (!atomic) {
      if (*out_buf > val) {
        *out_buf = val;
        *arg_u_buf = uid;
        *arg_e_buf = eid;
      }
    } else {
      cuda::AtomicMin(out_buf, val);
    }
  }
  static __device__ __forceinline__ bool RequireArg() {
    return true;
  }
  static __device__ __forceinline__ void CallArg(Idx fid,
    Idx *arg_u_buf, Idx *arg_e_buf,
    DType val, DType val_ref, Idx uid, Idx eid) {
    if (atomic) {
      if (val == val_ref) {
        if (arg_u_buf)
          arg_u_buf[fid] = uid; // TODO(zihao): select min?
        if (arg_e_buf)
          arg_e_buf[fid] = eid;
      }
    }
  }
};

}   // end of namespace reduce

}
}
}